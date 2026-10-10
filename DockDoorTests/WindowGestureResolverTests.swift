import CoreGraphics
@testable import DockDoor
import Testing

struct WindowGestureResolverTests {
    private func resolve(
        _ zone: WindowGestureZoneKind = .window(isFullscreen: false),
        steps: [GestureStep] = [],
        held: Bool = false,
        doubleTap: Bool = false,
        modifiers: Set<GestureModifierRole> = [],
        isPortrait: Bool = false,
        hasOtherDisplays: Bool = true,
        disabled: Set<WindowGesture> = WindowGesture.disabledByDefault
    ) -> WindowGestureCommand? {
        WindowGestureResolver.resolve(WindowGestureContext(
            zone: zone,
            progress: GestureProgress(steps: steps, held: held),
            doubleTap: doubleTap,
            modifiers: modifiers,
            isPortrait: isPortrait,
            hasOtherDisplays: hasOtherDisplays,
            disabled: disabled
        ))?.command
    }

    @Test func titleBarSwipesSnapToHalvesAndQuarters() {
        #expect(resolve(steps: [.left]) == .snap(.leftHalf))
        #expect(resolve(steps: [.right]) == .snap(.rightHalf))
        #expect(resolve(steps: [.right, .down]) == .snap(.bottomRightQuarter))
        #expect(resolve(steps: [.down, .right]) == .snap(.bottomRightQuarter))
        #expect(resolve(steps: [.up, .left]) == .snap(.topLeftQuarter))
        #expect(resolve(steps: [.left, .down]) == .snap(.bottomLeftQuarter))
        #expect(resolve(steps: [.right, .up]) == .snap(.topRightQuarter))
    }

    @Test func verticalSwipesFillMinimizeAndSplit() {
        #expect(resolve(steps: [.up]) == .snap(.maximize))
        #expect(resolve(steps: [.up, .up]) == .snap(.topHalf))
        #expect(resolve(steps: [.down]) == .minimize)
        #expect(resolve(steps: [.down, .down]) == .snap(.bottomHalf))
    }

    @Test func almostFillReplacesFillWhenEnabled() {
        #expect(resolve(steps: [.up], disabled: []) == .snap(.almostMaximize))
        #expect(resolve(steps: [.up], disabled: [.snapMax, .snapAlmost]) == nil)
    }

    @Test func disabledGesturesResolveToNothing() {
        #expect(resolve(steps: [.left], disabled: [.snapHalves]) == nil)
        #expect(resolve(steps: [.pinchIn], disabled: [.windowClose]) == nil)
    }

    @Test func pinchesCloseQuitAndFullScreen() {
        #expect(resolve(steps: [.pinchIn]) == .close)
        #expect(resolve(steps: [.pinchIn, .pinchIn]) == .quitApp)
        #expect(resolve(steps: [.pinchIn], held: true) == .quitApp)
        #expect(resolve(steps: [.pinchOut]) == .toggleFullScreen)
        #expect(resolve(steps: [.pinchOut, .pinchOut]) == .fullScreenOnOtherDisplay)
        #expect(resolve(steps: [.pinchOut], modifiers: [.screen]) == .fullScreenOnOtherDisplay)
        #expect(resolve(steps: [.pinchOut, .pinchOut], hasOtherDisplays: false) == nil)
        #expect(resolve(steps: [.pinchOut], modifiers: [.screen], hasOtherDisplays: false) == .toggleFullScreen)
    }

    @Test func doubleTapCentersOrHides() {
        #expect(resolve(doubleTap: true) == .center)
        #expect(resolve(doubleTap: true, modifiers: [.general]) == .hideApp)
        #expect(resolve(doubleTap: true, modifiers: [.secondary]) == .hideOtherApps)
    }

    @Test func generalModifierClosesQuitsAndMovesSpaces() {
        #expect(resolve(steps: [.down], modifiers: [.general]) == .close)
        #expect(resolve(steps: [.down, .down], modifiers: [.general]) == .quitApp)
        #expect(resolve(steps: [.right], modifiers: [.general]) == .moveToSpace(offset: 1))
        #expect(resolve(steps: [.left, .left], modifiers: [.general]) == .moveToSpace(offset: -2))
    }

    @Test func tapAndHoldMovesSpacesAndTogglesFullScreen() {
        #expect(resolve(steps: [.left], held: true) == .moveToSpace(offset: -1))
        #expect(resolve(steps: [.up], held: true) == .toggleFullScreen)
        #expect(resolve(steps: [.down], held: true) == .minimize)
        #expect(resolve(held: true) == nil)
    }

    @Test func screenModifierMovesBetweenDisplays() {
        #expect(resolve(steps: [.right], modifiers: [.screen]) == .moveToDisplay(.right))
        #expect(resolve(steps: [.left, .up], modifiers: [.screen]) == .moveToDisplay(.up))
    }

    @Test func secondaryModifierSnapsToThirdsAndSixths() {
        let leftThird = SnapRegion(columns: 3, rows: 1, columnSpan: 0 ... 0, rowSpan: 0 ... 0)
        let leftTwoThirds = SnapRegion(columns: 3, rows: 1, columnSpan: 0 ... 1, rowSpan: 0 ... 0)
        let rightThird = SnapRegion(columns: 3, rows: 1, columnSpan: 2 ... 2, rowSpan: 0 ... 0)
        let rightTwoThirds = SnapRegion(columns: 3, rows: 1, columnSpan: 1 ... 2, rowSpan: 0 ... 0)
        let middleThird = SnapRegion(columns: 3, rows: 1, columnSpan: 1 ... 1, rowSpan: 0 ... 0)
        #expect(resolve(steps: [.left], modifiers: [.secondary]) == .snap(leftThird))
        #expect(resolve(steps: [.left, .left], modifiers: [.secondary]) == .snap(leftTwoThirds))
        #expect(resolve(steps: [.right], modifiers: [.secondary]) == .snap(rightThird))
        #expect(resolve(steps: [.right, .right], modifiers: [.secondary]) == .snap(rightTwoThirds))
        #expect(resolve(held: true, modifiers: [.secondary]) == .snap(middleThird))
        #expect(resolve(steps: [.left, .up], modifiers: [.secondary]) == .snap(SnapRegion(columns: 3, rows: 2, columnSpan: 0 ... 0, rowSpan: 0 ... 0)))
        #expect(resolve(steps: [.down], held: true, modifiers: [.secondary]) == .snap(SnapRegion(columns: 3, rows: 2, columnSpan: 1 ... 1, rowSpan: 1 ... 1)))
        #expect(resolve(steps: [.up], modifiers: [.secondary]) == .snap(.maximize))
    }

    @Test func portraitScreensUseVerticalThirds() {
        let topThird = SnapRegion(columns: 1, rows: 3, columnSpan: 0 ... 0, rowSpan: 0 ... 0)
        #expect(resolve(steps: [.up], modifiers: [.secondary], isPortrait: true) == .snap(topThird))
        #expect(resolve(steps: [.down, .down], modifiers: [.secondary], isPortrait: true) == .snap(SnapRegion(columns: 1, rows: 3, columnSpan: 0 ... 0, rowSpan: 1 ... 2)))
    }

    @Test func tertiaryModifierSnapsToNinths() {
        #expect(resolve(steps: [.left, .up], modifiers: [.tertiary]) == .snap(SnapRegion(columns: 3, rows: 3, columnSpan: 0 ... 0, rowSpan: 0 ... 0)))
        #expect(resolve(steps: [.right, .right, .down, .down], modifiers: [.tertiary]) == .snap(SnapRegion(columns: 3, rows: 3, columnSpan: 1 ... 2, rowSpan: 1 ... 2)))
        #expect(resolve(steps: [.up], modifiers: [.tertiary]) == .snap(SnapRegion(columns: 3, rows: 3, columnSpan: 0 ... 2, rowSpan: 0 ... 0)))
    }

    @Test func tabsCloseAndDetach() {
        #expect(resolve(.tab(isFullscreen: false), steps: [.pinchIn]) == .closeTab)
        #expect(resolve(.tab(isFullscreen: false), held: true) == .detachTab)
        #expect(resolve(.tab(isFullscreen: false), steps: [.pinchIn, .pinchIn]) == .quitApp)
        #expect(resolve(.tab(isFullscreen: false), steps: [.left]) == .snap(.leftHalf))
    }

    @Test func fullScreenWindowsIgnoreSnapping() {
        #expect(resolve(.window(isFullscreen: true), steps: [.left]) == nil)
        #expect(resolve(.window(isFullscreen: true), steps: [.down]) == nil)
        #expect(resolve(.window(isFullscreen: true), steps: [.down], held: true) == .minimize)
        #expect(resolve(.window(isFullscreen: true), steps: [.pinchOut]) == .toggleFullScreen)
        #expect(resolve(.window(isFullscreen: true), doubleTap: true) == nil)
    }

    @Test func dockIconGestures() {
        #expect(resolve(.app, steps: [.left]) == .cycleWindows(forward: false))
        #expect(resolve(.app, steps: [.right]) == .cycleWindows(forward: true))
        #expect(resolve(.app, steps: [.up]) == .restoreLastMinimized)
        #expect(resolve(.app, steps: [.up], modifiers: [.secondary]) == .restoreAllMinimized)
        #expect(resolve(.app, steps: [.down]) == .minimizeFrontWindow)
        #expect(resolve(.app, steps: [.down], modifiers: [.secondary]) == .minimizeAllWindows)
        #expect(resolve(.app, steps: [.pinchIn]) == .quitApp)
        #expect(resolve(.app, steps: [.pinchIn, .pinchIn]) == .minimizeAllWindows)
        #expect(resolve(.app, steps: [.pinchOut]) == .newTabOrWindow)
        #expect(resolve(.app, steps: [.pinchOut, .pinchOut]) == .restoreAllMinimized)
        #expect(resolve(.app, doubleTap: true) == .toggleHidden)
        #expect(resolve(.app, doubleTap: true, modifiers: [.secondary]) == .hideOtherApps)
        #expect(resolve(.app, held: true) == .pickUpFrontWindow)
    }

    @Test func menuBarGestures() {
        #expect(resolve(.menuBar, steps: [.left]) == .switchApp(forward: false))
        #expect(resolve(.menuBar, steps: [.right]) == .switchApp(forward: true))
        #expect(resolve(.menuBar, steps: [.down]) == .minimizeAllOnDisplay(allDisplays: false))
        #expect(resolve(.menuBar, steps: [.down, .down]) == .minimizeAllOnDisplay(allDisplays: true))
        #expect(resolve(.menuBar, steps: [.up], modifiers: [.secondary]) == .restoreAllOnDisplay(allDisplays: true))
        #expect(resolve(.menuBar, doubleTap: true) == .unsnapAll(allDisplays: false))
        #expect(resolve(.menuBar, steps: [.right], held: true) == .openSwitcher)
        #expect(resolve(.menuBar, steps: [.left], modifiers: [.screen]) == .moveSnappedWindows(.left))
        #expect(resolve(.menuBar, steps: [.pinchIn]) == nil)
    }

    @Test func immediateCommandsAreTheOnesThatActMidGesture() {
        #expect(WindowGestureCommand.cycleWindows(forward: true).isImmediate)
        #expect(WindowGestureCommand.cycleWindows(forward: true).chainsWindow)
        #expect(WindowGestureCommand.moveToDisplay(.left).isImmediate)
        #expect(!WindowGestureCommand.moveToDisplay(.left).chainsWindow)
        #expect(!WindowGestureCommand.snap(.leftHalf).isImmediate)
        #expect(!WindowGestureCommand.minimizeFrontWindow.isImmediate)
    }
}
