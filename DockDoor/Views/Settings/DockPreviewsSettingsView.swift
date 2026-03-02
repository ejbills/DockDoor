import Defaults
import SwiftUI

struct DockPreviewsSettingsView: View {
    @Default(.enableDockPreviews) var enableDockPreviews
    @Default(.showWindowsFromCurrentSpaceOnly) var showWindowsFromCurrentSpaceOnly
    @Default(.windowPreviewSortOrder) var windowPreviewSortOrder
    @Default(.keepPreviewOnAppTerminate) var keepPreviewOnAppTerminate
    @Default(.groupAppInstancesInDock) var groupAppInstancesInDock
    @Default(.includeHiddenWindowsInDockPreview) var includeHiddenWindowsInDockPreview
    @Default(.previewHoverAction) var previewHoverAction
    @Default(.tapEquivalentInterval) var tapEquivalentInterval
    @Default(.shouldHideOnDockItemClick) var shouldHideOnDockItemClick
    @Default(.dockClickAction) var dockClickAction
    @Default(.enableCmdRightClickQuit) var enableCmdRightClickQuit
    @Default(.quitAppOnWindowClose) var quitAppOnWindowClose
    @Default(.bufferFromDock) var bufferFromDock

    var body: some View {
        BaseSettingsView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection

                if enableDockPreviews {
                    windowDisplaySection
                    dockInteractionSection
                    dockAppearanceSection
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        SettingsGroup {
            SettingsIllustratedToggle(
                isOn: $enableDockPreviews,
                title: "Enable Dock Previews",
                imageName: "DockPreviews"
            ) {
                Text("Show window previews when hovering over Dock icons.")
            }
            .onChange(of: enableDockPreviews) { _ in askUserToRestartApplication() }
        }
    }

    // MARK: - Window Display

    private var windowDisplaySection: some View {
        SettingsGroup(header: "Window Display") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $showWindowsFromCurrentSpaceOnly) { Text("Show windows from current Space only") }
                Text("Only display windows that are in the current virtual desktop/Space.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Picker("Window sort order", selection: $windowPreviewSortOrder) {
                    ForEach(WindowPreviewSortOrder.allCases.filter { !$0.isWindowSwitcherOnly }) { order in
                        Text(order.localizedName).tag(order)
                    }
                }
                .pickerStyle(.menu)

                Toggle(isOn: $includeHiddenWindowsInDockPreview) { Text("Include hidden/minimized windows") }

                Toggle(isOn: $keepPreviewOnAppTerminate) { Text("Keep preview when app terminates") }
                Text("Remove only terminated app's windows instead of hiding the entire preview.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle(isOn: $groupAppInstancesInDock) { Text("Group multiple app instances together") }
                Text("Show windows from all instances of an app when hovering its dock icon.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }
        }
    }

    // MARK: - Appearance

    private var dockAppearanceSection: some View {
        SettingsGroup(header: "Appearance") {
            DockPreviewAppearanceSection()
        }
    }

    // MARK: - Dock Interaction

    private var dockInteractionSection: some View {
        SettingsGroup(header: "Dock Interaction") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Dock Preview Hover Action", selection: $previewHoverAction) {
                    ForEach(PreviewHoverAction.allCases, id: \.self) { Text($0.localizedName).tag($0) }
                }
                .pickerStyle(MenuPickerStyle())

                sliderSetting(title: "Preview Hover Action Delay", value: $tapEquivalentInterval, range: 0 ... 2, step: 0.1, unit: "seconds", formatter: NumberFormatter.oneDecimalFormatter)
                    .disabled(previewHoverAction == .none)

                Toggle(isOn: $shouldHideOnDockItemClick) { Text("Hide all app windows on dock icon click") }
                if shouldHideOnDockItemClick {
                    Picker("Dock Click Action", selection: $dockClickAction) {
                        ForEach(DockClickAction.allCases, id: \.self) {
                            Text($0.localizedName).tag($0)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding(.leading, 20)
                }

                Toggle(isOn: $enableCmdRightClickQuit) { Text("CMD + Right Click on dock icon to quit app") }

                Toggle(isOn: $quitAppOnWindowClose) { Text("Quit app when closing its last window") }
                Text("When an app has only one window left, closing it from the preview will quit the app. Hold Option to force quit. Useful as a replacement for Swift Quit.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                sliderSetting(title: "Window Buffer from Dock (pixels)", value: $bufferFromDock, range: -100 ... 100, step: 5, unit: "px", formatter: { let f = NumberFormatter(); f.allowsFloats = false; f.minimumIntegerDigits = 1; f.maximumFractionDigits = 0; return f }())
            }
        }
    }
}
