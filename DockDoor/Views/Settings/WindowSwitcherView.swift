import Defaults
import SwiftUI

struct WindowSwitcherView: View {
    @Default(.showWindowTitleInSwitcher) private var showWindowTitleInSwitcher: Bool
    @Default(.enableWindowSwitcher) private var enableWindowSwitcher: Bool
    @Default(.includeHiddenWindowsInSwitcher) private var includeHiddenWindowsInSwitcher: Bool
    @Default(.windowSwitcherPlacementStrategy) private var placementStrategy: WindowSwitcherPlacementStrategy
    @Default(.pinnedScreenIdentifier) private var pinnedScreenIdentifier: String
    @Default(.useClassicWindowOrdering) private var useClassicWindowOrdering: Bool
    @Default(.windowSwitcherControlPosition) private var windowSwitcherControlPosition: WindowSwitcherControlPosition

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hero Image
                VStack(spacing: 8) {
                    Image("WindowSwitcherSettings")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(radius: 10)
                    Text("Window Switcher")
                        .font(.system(size: 28, weight: .bold))
                }
                .frame(maxWidth: .infinity)

                // Enable Toggle
                HStack {
                    Spacer()
                    Toggle(isOn: $enableWindowSwitcher) {
                        Text("Enable Window Switcher")
                    }
                    .onChange(of: enableWindowSwitcher) { _ in
                        askUserToRestartApplication()
                    }
                    Spacer()
                }

                // Appearance Settings
                VStack(alignment: .leading, spacing: 8) {
                    Text("Appearance").font(.headline)

                    Toggle(isOn: $showWindowTitleInSwitcher) {
                        Text("Show window titles.")
                    }

                    Toggle(isOn: $includeHiddenWindowsInSwitcher) {
                        Text("Include hidden and minimized windows.")
                    }

                    Picker("Controls position", selection: $windowSwitcherControlPosition) {
                        ForEach(WindowSwitcherControlPosition.allCases, id: \.self) { position in
                            Text(position.localizedName).tag(position)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color(NSColor.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.separator)
                )

                // Behaviour Settings
                VStack(alignment: .leading, spacing: 8) {
                    Text("Behaviour").font(.headline)

                    Toggle(isOn: $useClassicWindowOrdering) {
                        Text("Show last active window first (matches Windows 11 behaviour)")
                    }

                    Picker("Placement strategy", selection: $placementStrategy) {
                        ForEach(WindowSwitcherPlacementStrategy.allCases, id: \.self) { strategy in
                            Text(strategy.localizedName).tag(strategy)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: placementStrategy) { newStrategy in
                        if newStrategy == .pinnedToScreen, pinnedScreenIdentifier.isEmpty {
                            pinnedScreenIdentifier = NSScreen.main?.uniqueIdentifier() ?? ""
                        }
                    }

                    if placementStrategy == .pinnedToScreen {
                        Picker("Pin to Screen", selection: $pinnedScreenIdentifier) {
                            ForEach(NSScreen.screens, id: \.self) { screen in
                                Text(screenDisplayName(screen))
                                    .tag(screen.uniqueIdentifier())
                            }

                            if !pinnedScreenIdentifier.isEmpty,
                               !NSScreen.screens.contains(where: { $0.uniqueIdentifier() == pinnedScreenIdentifier })
                            {
                                Text("Disconnected Display")
                                    .tag(pinnedScreenIdentifier)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())

                        if !pinnedScreenIdentifier.isEmpty,
                           !NSScreen.screens.contains(where: { $0.uniqueIdentifier() == pinnedScreenIdentifier })
                        {
                            Text("This display is currently disconnected. The window switcher will appear on the main display until the selected display is reconnected.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color(NSColor.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.separator)
                )
            }
            .padding(24)
        }
        .frame(minWidth: 500, maxWidth: 500, minHeight: 750, maxHeight: 750)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func screenDisplayName(_ screen: NSScreen) -> String {
        let isMain = screen == NSScreen.main
        if !screen.localizedName.isEmpty {
            return "\(screen.localizedName)\(isMain ? " (Main)" : "")"
        } else {
            return "Disconnected Display"
        }
    }
}
