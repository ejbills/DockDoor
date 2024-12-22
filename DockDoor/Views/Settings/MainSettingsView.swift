import Defaults
import LaunchAtLogin
import SwiftUI

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
    @Default(.lateralMovement) var lateralMovement
    @Default(.preventDockHide) var preventDockHide
    @Default(.useClassicWindowOrdering) private var useClassicWindowOrdering

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

            VStack(alignment: .leading) {
                Toggle(isOn: $preventDockHide, label: {
                    Text("Prevent dock from hiding during previews")
                })
                Text("Only takes effect when dock auto-hide is enabled")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }

            sliderSetting(title: String(localized: "Preview Window Open Delay"),
                          value: $hoverWindowOpenDelay,
                          range: 0 ... 2,
                          step: 0.1,
                          unit: String(localized: "seconds"),
                          formatter: NumberFormatter.oneDecimalFormatter)

            sliderSetting(title: String(localized: "Preview Window Fade Out Duration"),
                          value: $fadeOutDuration,
                          range: 0 ... 2,
                          step: 0.1,
                          unit: String(localized: "seconds"),
                          formatter: NumberFormatter.oneDecimalFormatter)

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

            WindowSizeSliderView()

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

            VStack(alignment: .leading) {
                Toggle(isOn: $useClassicWindowOrdering) {
                    Text("Use classic window ordering")
                }
                Text("When enabled, shows the last active window first instead of the current window")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }

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
                          unit: String(localized: "seconds"),
                          formatter: NumberFormatter.oneDecimalFormatter)
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

struct WindowSizeSliderView: View {
    @Default(.sizingMultiplier) var sizingMultiplier

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Slider(value: $sizingMultiplier, in: 2 ... 10, step: 1) {
                    Text("Window Preview Size")
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 400)

                Text("1/\(Int(sizingMultiplier))x")
                    .frame(width: 50)
                    .foregroundColor(.gray)
            }

            Text("Preview windows are sized to 1/\(Int(sizingMultiplier)) of your screen dimensions")
                .font(.footnote)
                .foregroundColor(.gray)
        }
        .onChange(of: sizingMultiplier) { _ in
            SharedPreviewWindowCoordinator.shared.windowSize = getWindowSize()
        }
    }
}
