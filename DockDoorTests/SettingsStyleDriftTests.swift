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

    private static let convertedPanes = ["DockPreviewsSettingsView.swift"]

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

    @Test func convertedPanesUseTheFormKit() throws {
        for pane in convertedPanes {
            let source = try String(contentsOf: sourceRoot.appendingPathComponent(pane), encoding: .utf8)
            #expect(source.contains("SettingsFormView"), "\(pane) should be built on SettingsFormView")
            #expect(source.contains("SettingsSection("), "\(pane) should use SettingsSection for groups")
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

    /// Collects the lines of the statement that starts at `startLine`: the
    /// contiguous run of lines at the same or deeper indentation, so a
    /// modifier chain like `.buttonStyle(...)` counts as part of the call.
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
            if leading > atIndent || (leading == atIndent && trimmed.hasPrefix(".")) {
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
