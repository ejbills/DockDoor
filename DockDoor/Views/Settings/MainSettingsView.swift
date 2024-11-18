import Defaults
import LaunchAtLogin
import SwiftUI

var decimalFormatter: NumberFormatter {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 1
    return formatter
}

struct MainSettingsView: View {
    @Default(.hoverWindowOpenDelay) var hoverWindowOpenDelay
    @Default(.screenCaptureCacheLifespan) var screenCaptureCacheLifespan
    @Default(.showMenuBarIcon) var showMenuBarIcon
    @Default(.tapEquivalentInterval) var tapEquivalentInterval
    @Default(.previewHoverAction) var previewHoverAction
    @Default(.bufferFromDock) var bufferFromDock
    @Default(.windowPreviewImageScale) var windowPreviewImageScale
    @Default(.fadeOutDuration) var fadeOutDuration
    @Default(.sortWindowsByDate) var sortWindowsByDate
    @Default(.ignoreAppsWithSingleWindow) var ignoreAppsWithSingleWindow
    @Default(.lateralMovement) var lateralMovement

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Section {
                HStack {
                    Text("Want to support development?")
                    Link("Buy me a coffee here, thank you!", destination: URL(string: "https://www.buymeacoffee.com/keplercafe")!)
                }

                HStack {
                    Text("Want to see the app in your language?")
                    Link("Contribute translation here!", destination: URL(string: "https://crowdin.com/project/dockdoor/invite?h=895e3c085646d3c07fa36a97044668e02149115")!)
                }
            }

            Divider()

            LaunchAtLogin.Toggle(String(localized: "Launch DockDoor at login"))

            Toggle(isOn: $showMenuBarIcon, label: {
                Text("Show Menu Bar Icon")
            })
            .onChange(of: showMenuBarIcon) { isOn in
                let appDelegate = NSApplication.shared.delegate as! AppDelegate
                if isOn {
                    appDelegate.setupMenuBar()
                } else {
                    appDelegate.removeMenuBar()
                }
            }

            Button("Reset All Settings to Defaults") {
                showResetConfirmation()
            }
            Button("Quit DockDoor") {
                let appDelegate = NSApplication.shared.delegate as! AppDelegate
                appDelegate.quitApp()
            }

            Divider()

            VStack(alignment: .leading) {
                Toggle(isOn: $lateralMovement, label: {
                    Text("Keep previews visible during lateral movement")
                })
                Text("Prevents previews from disappearing when moving sideways to adjacent windows")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }

            sliderSetting(title: String(localized: "Preview Window Open Delay"),
                          value: $hoverWindowOpenDelay,
                          range: 0 ... 2,
                          step: 0.1,
                          unit: String(localized: "seconds"))

            sliderSetting(title: String(localized: "Preview Window Fade Out Duration"),
                          value: $fadeOutDuration,
                          range: 0 ... 2,
                          step: 0.1,
                          unit: String(localized: "seconds"))

            VStack(alignment: .leading) {
                HStack {
                    Slider(value: $bufferFromDock, in: -200 ... 200, step: 20) {
                        Text("Window Buffer")
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 400)
                    TextField("", value: $bufferFromDock, formatter: NumberFormatter())
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 50)
                }
                Text("Adjust this if the preview is misaligned with dock")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }

            SizePickerView()

            sliderSetting(title: String(localized: "Window Image Cache Lifespan"),
                          value: $screenCaptureCacheLifespan,
                          range: 0 ... 60,
                          step: 5,
                          unit: String(localized: "seconds"))

            sliderSetting(title: String(localized: "Window Image Resolution Scale (higher means lower resolution)"),
                          value: $windowPreviewImageScale,
                          range: 1 ... 4,
                          step: 1,
                          unit: "")

            Toggle(isOn: $sortWindowsByDate, label: {
                Text("Sort Window Previews by Date")
            })

            Toggle(isOn: $ignoreAppsWithSingleWindow, label: {
                Text("Ignore Apps with One Window")
            })

            Picker("Preview Hover Action", selection: $previewHoverAction) {
                ForEach(PreviewHoverAction.allCases, id: \.self) { action in
                    Text(action.localizedName).tag(action)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .scaledToFit()

            sliderSetting(title: String(localized: "Preview Hover Delay"),
                          value: $tapEquivalentInterval,
                          range: 0 ... 2,
                          step: 0.1,
                          unit: String(localized: "seconds"))
                .disabled(previewHoverAction == .none)
        }
        .padding(20)
        .frame(minWidth: 650)
    }

    private func showResetConfirmation() {
        MessageUtil.showAlert(
            title: String(localized: "Reset to Defaults"),
            message: String(localized: "Are you sure you want to reset all settings to their default values?"),
            actions: [.ok, .cancel]
        ) { action in
            switch action {
            case .ok:
                resetDefaultsToDefaultValues()
            case .cancel:
                // Do nothing
                break
            }
        }
    }
}

struct SizePickerView: View {
    @Default(.sizingMultiplier) var sizingMultiplier
    @Default(.bufferFromDock) var bufferFromDock

    var body: some View {
        VStack(spacing: 20) {
            Picker("Window Size", selection: $sizingMultiplier) {
                ForEach(2 ... 10, id: \.self) { size in
                    Text(getLabel(for: CGFloat(size))).tag(CGFloat(size))
                }
            }
            .scaledToFit()
            .onChange(of: sizingMultiplier) { _ in
                SharedPreviewWindowCoordinator.shared.windowSize = getWindowSize()
            }
        }
    }

    private func getLabel(for size: CGFloat) -> String {
        switch size {
        case 2:
            String(localized: "Large", comment: "Window size option")
        case 3:
            String(localized: "Default (Medium Large)", comment: "Window size option")
        case 4:
            String(localized: "Medium", comment: "Window size option")
        case 5:
            String(localized: "Small", comment: "Window size option")
        case 6:
            String(localized: "Extra Small", comment: "Window size option")
        case 7:
            String(localized: "Extra Extra Small", comment: "Window size option")
        case 8:
            String(localized: "What is this? A window for ANTS?", comment: "Window size option")
        case 9:
            String(localized: "Subatomic", comment: "Window size option")
        case 10:
            String(localized: "Can you even see this?", comment: "Window size option")
        default:
            "Unknown Size"
        }
    }
}
