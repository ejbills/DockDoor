import SwiftUI

/// Bare rows for a Form section, shared by all three surfaces so the captions can't drift.
struct SharedWindowDisplayRows: View {
    let currentSpaceOnly: Binding<Bool>
    let currentSpaceOnlyTarget: String
    let monitorCaption: LocalizedStringKey
    let currentMonitorOnly: Binding<Bool>
    let currentMonitorOnlyTarget: String
    let includeHidden: Binding<Bool>
    let includeHiddenTarget: String
    let showWindowless: Binding<Bool>
    let showWindowlessTarget: String
    let windowlessTitle: LocalizedStringKey
    let windowlessCaption: LocalizedStringKey
    var ignoreSingleWindow: Binding<Bool>?
    var ignoreSingleWindowTarget: String?
    var ignoreSingleWindowCaption: LocalizedStringKey?

    var body: some View {
        Toggle(isOn: currentSpaceOnly) { Text("Show windows from current Space only") }
            .settingsSearchTarget(currentSpaceOnlyTarget)
            .settingsAnnotation("Only display windows that are in the current virtual desktop/Space.")

        Toggle(isOn: currentMonitorOnly) { Text("Show windows from current monitor only") }
            .settingsSearchTarget(currentMonitorOnlyTarget)
            .settingsAnnotation(monitorCaption)

        Toggle(isOn: includeHidden) { Text("Include hidden/minimized windows") }
            .settingsSearchTarget(includeHiddenTarget)

        Toggle(isOn: showWindowless) { Text(windowlessTitle) }
            .settingsSearchTarget(showWindowlessTarget)
            .settingsAnnotation(windowlessCaption)

        if let ignoreSingleWindow, let ignoreSingleWindowTarget, let ignoreSingleWindowCaption {
            Toggle(isOn: ignoreSingleWindow) { Text("Ignore apps with one window") }
                .settingsSearchTarget(ignoreSingleWindowTarget)
                .settingsAnnotation(ignoreSingleWindowCaption)
        }
    }
}
