import Foundation
import Testing

/// Guards the settings form style from drifting. Rules apply to the panes
/// listed in `convertedPanes`; add a pane there as it adopts the form kit
/// (`SettingsFormView` + `SettingsSection` + `.settingsAnnotation`).
///
/// - Pickers must be menu style: no segmented, radio group, inline or wheel.
/// - Every `Button` carries an explicit `.buttonStyle(...)`.
/// - No bordered buttons: panes use plain rows, kit styles or no button.
struct SettingsStyleDriftTests {
    private static let sourceRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // DockDoorTests
        .deletingLastPathComponent() // repo root
        .appendingPathComponent("DockDoor/Views/Settings", isDirectory: true)

    private static let convertedPanes = [
        "DockPreviewsSettingsView.swift",
        "MainSettingsView.swift",
        "WindowSwitcherBehaviorSettingsView.swift",
        "GesturesSettingsView.swift",
        "CmdTabSettingsView.swift",
        "AppearanceSettingsView.swift",
        "KeybindsSettingsView.swift",
        "FiltersSettingsView.swift",
        "WidgetSettingsView.swift",
        "AdvancedSettingsView.swift",
        "SupportSettingsView.swift",
    ]

    private static let bannedPickerStyles = [
        ".pickerStyle(.segmented",
        ".pickerStyle(.radioGroup",
        ".pickerStyle(.inline",
        ".pickerStyle(.wheel",
        "pickerStyle(MenuPickerStyle())", // legacy spelling; .menu is the convention
        "pickerStyle(DefaultPickerStyle())",
    ]

    private static let bannedButtonStyles = [
        ".buttonStyle(.borderedProminent",
        ".buttonStyle(.bordered)",
        ".buttonStyle(BorderedButtonStyle()",
    ]

    @Test func convertedPanesExist() {
        for pane in convertedPanes {
            let file = sourceRoot.appendingPathComponent(pane)
            #expect(FileManager.default.fileExists(atPath: file.path), "Missing converted pane source: \(pane)")
        }
    }

    /// A modifier after a control-flow block's `}` has no base view and fails to build.
    /// Checked in every settings source, not only the converted panes.
    @Test func settingsSourcesDoNotChainModifiersOntoControlFlow() throws {
        for file in try settingsSourceFiles() {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: .newlines)
            for index in lines.indices {
                let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("."), Self.modifierChainPattern.firstMatch(in: trimmed) != nil else { continue }

                var previous = index - 1
                while previous >= 0, lines[previous].trimmingCharacters(in: .whitespaces).isEmpty {
                    previous -= 1
                }
                guard previous >= 0, lines[previous].trimmingCharacters(in: .whitespaces) == "}", let openerIndex = blockOpenerIndex(in: lines, closingAt: previous) else { continue }
                let openerText = lines[openerIndex].trimmingCharacters(in: .whitespaces)
                let isControlFlow = openerText.hasPrefix("if ")
                    || openerText.hasPrefix("if(")
                    || openerText.hasPrefix("ForEach")
                    || openerText.hasPrefix("switch ")
                    || openerText.hasSuffix("else {")

                #expect(
                    !isControlFlow,
                    "\(file.lastPathComponent):\(index + 1) chains \(trimmed) onto the block opened at line \(openerIndex + 1) (\(openerText.prefix(50))); wrap the block in a Group"
                )
            }
        }
    }

    private static let modifierChainPattern = try! NSRegularExpression(
        pattern: #"^\.(disabled|opacity|animation|onChange|onHover|padding|frame|help|controlSize|background|fixedSize|foregroundColor|hidden)\("#
    )

    private func settingsSourceFiles() throws -> [URL] {
        let enumerator = FileManager.default.enumerator(at: Self.sourceRoot, includingPropertiesForKeys: nil)
        return ((enumerator?.allObjects as? [URL]) ?? []).filter { $0.pathExtension == "swift" }
    }

    /// Index of the line that opened the block closed on `closingAt`.
    private func blockOpenerIndex(in lines: [String], closingAt closeIndex: Int) -> Int? {
        var depth = 0
        var index = closeIndex
        while index >= 0 {
            for character in lines[index].reversed() {
                if character == "}" {
                    depth += 1
                } else if character == "{" {
                    depth -= 1
                    if depth == 0 {
                        return index
                    }
                }
            }
            index -= 1
        }
        return nil
    }

    @Test func convertedPanesUseTheFormKit() throws {
        for pane in convertedPanes {
            let source = try String(contentsOf: sourceRoot.appendingPathComponent(pane), encoding: .utf8)
            #expect(source.contains("SettingsFormView"), "\(pane) should be built on SettingsFormView")
            // Some panes compose section views that carry their own SettingsSections.
            #expect(
                source.contains("SettingsSection(") || source.contains("Section()"),
                "\(pane) should use SettingsSection for groups"
            )
        }
    }

    @Test func convertedPanesUseMenuPickersOnly() throws {
        for pane in convertedPanes {
            let source = try String(contentsOf: sourceRoot.appendingPathComponent(pane), encoding: .utf8)
            for banned in bannedPickerStyles {
                #expect(!source.contains(banned), "\(pane) uses \(banned); menu pickers only")
            }
        }
    }

    @Test func convertedPanesAvoidBorderedButtons() throws {
        for pane in convertedPanes {
            let source = try String(contentsOf: sourceRoot.appendingPathComponent(pane), encoding: .utf8)
            let withoutComments = stripLineComments(source)
            for banned in bannedButtonStyles {
                #expect(!withoutComments.contains(banned), "\(pane) uses \(banned); bordered buttons are not part of the settings style")
            }
        }
    }

    @Test func convertedPanesStyleEveryButton() throws {
        for pane in convertedPanes {
            let source = try stripLineComments(String(contentsOf: sourceRoot.appendingPathComponent(pane), encoding: .utf8))
            let lines = source.components(separatedBy: .newlines)

            var index = 0
            while index < lines.count {
                let line = lines[index]
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                guard trimmed.contains("Button(") || trimmed.hasPrefix("Button {") || trimmed.contains("Button(action") else {
                    index += 1
                    continue
                }

                // A bare type name in prose (e.g. DangerButton) is not a call site.
                let isCall = trimmed.contains("Button(") && !trimmed.contains("struct ") && !trimmed.contains("func ")
                guard isCall else {
                    index += 1
                    continue
                }

                let leading = line.count - line.drop(while: { $0 == " " || $0 == "\t" }).count
                let statement = contiguousStatement(in: lines, from: index, atIndent: leading)
                let lowercased = statement.lowercased()
                let hasStyle = lowercased.contains("buttonstyle(") || lowercased.contains("dangerbutton(") || lowercased.contains("accentbutton(")

                #expect(hasStyle, "\(pane):\(index + 1) has a Button without an explicit style:\n\(statement)")

                index += 1
            }
        }
    }

    /// The statement starting at `startLine`, following its modifier chain past the
    /// label closure, so a `.buttonStyle(...)` after the label still counts.
    private static func contiguousStatement(in lines: [String], from startLine: Int, atIndent: Int) -> String {
        var collected = [lines[startLine]]
        var index = startLine + 1

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                collected.append(line)
                index += 1
                continue
            }
            let leading = line.count - line.drop(while: { $0 == " " || $0 == "\t" }).count
            if leading > atIndent {
                collected.append(line)
                index += 1
            } else if leading == atIndent, trimmed.hasPrefix(".") || trimmed == "}" {
                collected.append(line)
                index += 1
            } else {
                break
            }
        }

        return collected.joined(separator: "\n")
    }

    private static func stripLineComments(_ source: String) -> String {
        source
            .components(separatedBy: .newlines)
            .map { line -> String in
                if let range = line.range(of: "//") {
                    return String(line[..<range.lowerBound])
                }
                return line
            }
            .joined(separator: "\n")
    }
}
