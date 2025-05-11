import Defaults
import SwiftUI

// Add enum for preview size
private enum DockPreviewSize: String, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }
    var label: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }

    var multiplier: Double {
        switch self {
        case .small: 8
        case .medium: 5.5
        case .large: 3
        }
    }
}

struct DockPreviewsView: View {
    @AppStorage("dockPreviewSize") private var dockPreviewSize: String = DockPreviewSize.small.rawValue
    @Default(.previewWrap) private var previewWrap: Int
    @Default(.showWindowTitle) private var showWindowTitle: Bool
    @Default(.windowTitleVisibility) private var windowTitleVisibility: WindowTitleVisibility
    @Default(.windowTitlePosition) private var windowTitlePosition: WindowTitlePosition
    @Default(.showAppName) private var showAppName: Bool
    @Default(.appNameStyle) private var appNameStyle: AppNameStyle
    @Default(.previewHoverAction) private var previewHoverAction: PreviewHoverAction
    @Default(.aeroShakeAction) private var aeroShakeAction: AeroShakeAction
    @Default(.sizingMultiplier) private var sizingMultiplier: CGFloat

    private var selectedSize: DockPreviewSize {
        DockPreviewSize(rawValue: dockPreviewSize) ?? .medium
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hero Image
                VStack(spacing: 8) {
                    Image("DockPreviewsSettings")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(radius: 10)
                    Text("Dock Previews")
                        .font(.system(size: 28, weight: .bold))
                }
                .frame(maxWidth: .infinity)

                // Size and Wrap section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Size").font(.headline)
                    Text("Small is equivalent to Windows 11.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Picker("Size:", selection: $dockPreviewSize) {
                        ForEach(DockPreviewSize.allCases) { size in
                            Text(size.label).tag(size.rawValue)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: dockPreviewSize) { newValue in
                        if let size = DockPreviewSize(rawValue: newValue) {
                            sizingMultiplier = size.multiplier
                            SharedPreviewWindowCoordinator.shared.windowSize = getWindowSize()
                        }
                    }

                    Spacer(minLength: 1)
                    Divider()
                    Spacer(minLength: 1)

                    Text("Layout Stacking Limits").font(.headline)

                    Text("Sets the maximum number of columns for arranging window previews. Previews fill each column \(DockUtils.getDockPosition().isHorizontalFlow ? "horizontally" : "vertically") before wrapping to a new column, up to this limit."
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    HStack {
                        Text("Wrap:")
                        Stepper(value: $previewWrap, in: 1 ... 10) {
                            TextField(
                                "",
                                value: $previewWrap,
                                formatter: NumberFormatter()
                            )
                            .frame(width: 40)
                            .multilineTextAlignment(.center)
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

                // Appearance section
                VStack(alignment: .leading, spacing: 8) {
                    // Labels subsection
                    Text("Labels and Controls").font(.headline)
                    Text("Control how app names, window titles, and controls are displayed.").font(.subheadline).foregroundColor(.secondary)
                    Spacer(minLength: 1)
                    Divider()
                    Spacer(minLength: 1)

                    // App Name settings
                    Text("App Name").font(.headline)
                    Toggle(isOn: $showAppName) {
                        Text("Show app name.")
                    }
                    Picker("App name style", selection: $appNameStyle) {
                        ForEach(AppNameStyle.allCases, id: \.self) { style in
                            Text(style.localizedName)
                                .tag(style)
                        }
                    }
                    .disabled(!showAppName)
                    Spacer(minLength: 1)
                    Divider()
                    Spacer(minLength: 1)
                    // Window Title settings
                    Text("Window Titles").font(.headline)
                    Toggle(isOn: $showWindowTitle) {
                        Text("Show window titles.")
                    }
                    Group {
                        Picker("Window title visibility", selection: $windowTitleVisibility) {
                            ForEach(WindowTitleVisibility.allCases, id: \.self) { visibility in
                                Text(visibility.localizedName)
                                    .tag(visibility)
                            }
                        }

                        Picker("Window title position", selection: $windowTitlePosition) {
                            ForEach(WindowTitlePosition.allCases, id: \.self) { position in
                                Text(position.localizedName)
                                    .tag(position)
                            }
                        }
                    }
                    .disabled(!showWindowTitle)

                    Spacer(minLength: 1)
                    Divider()
                    Spacer(minLength: 1)

                    // Traffic Light Buttons subsection
                    TrafficLightButtonsSettingsView()
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

                // Actions section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Actions").font(.headline)
                    Text("Configure how previews respond to mouse interactions.").font(.subheadline).foregroundColor(.secondary)
                    Spacer(minLength: 1)
                    Divider()
                    Spacer(minLength: 1)

                    VStack(alignment: .leading) {
                        Picker("Dock Preview Window Hover Action", selection: $previewHoverAction) {
                            ForEach(PreviewHoverAction.allCases, id: \.self) { action in
                                Text(action.localizedName).tag(action)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .scaledToFit()

                        Text("Triggers an action when hovering over a window in a dock preview")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer(minLength: 1)
                    Divider()
                    Spacer(minLength: 1)

                    VStack(alignment: .leading) {
                        Picker("Dock Preview Aero Shake Action", selection: $aeroShakeAction) {
                            ForEach(AeroShakeAction.allCases, id: \.self) { action in
                                Text(action.localizedName).tag(action)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .scaledToFit()

                        Text("Triggers an action when shaking a window while it is being dragged from a dock preview")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
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
}
