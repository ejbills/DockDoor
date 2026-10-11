import CoreGraphics
@testable import DockDoor
import Testing

struct WindowGestureResolverTests {
    private func resolve(
        _ zone: WindowGestureZoneKind = .window(isFullscreen: false),
        steps: [GestureStep] = [],
        held: Bool = false,
        doubleTap: Bool = false,
        disabled: Set<WindowGesture> = []
    ) -> WindowGestureCommand? {
        WindowGestureResolver.resolve(WindowGestureContext(
            zone: zone,
            progress: GestureProgress(steps: steps, held: held),
            doubleTap: doubleTap,
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

    @Test func verticalSwipesFillAndMinimize() {
        #expect(resolve(steps: [.up]) == .snap(.maximize))
        #expect(resolve(steps: [.down]) == .minimize)
        #expect(resolve(steps: [.up, .up]) == nil)
        #expect(resolve(steps: [.right, .right]) == nil)
    }

    @Test func holdingDoesNotChangeTitleBarSwipes() {
        #expect(resolve(steps: [.right], held: true) == .snap(.rightHalf))
        #expect(resolve(held: true) == nil)
    }

    @Test func disabledGesturesResolveToNothing() {
        #expect(resolve(steps: [.left], disabled: [.snapHalves]) == nil)
        #expect(resolve(steps: [.pinchIn], disabled: [.windowClose]) == nil)
        #expect(resolve(.app, steps: [.pinchIn], disabled: [.appQuit]) == nil)
    }

    @Test func pinchesCloseAndToggleFullScreen() {
        #expect(resolve(steps: [.pinchIn]) == .close)
        #expect(resolve(steps: [.pinchIn, .pinchIn]) == .close)
        #expect(resolve(steps: [.pinchOut]) == .toggleFullScreen)
        #expect(resolve(steps: [.pinchOut, .pinchOut]) == .toggleFullScreen)
    }

    @Test func doubleTapCenters() {
        #expect(resolve(doubleTap: true) == .center)
        #expect(resolve(doubleTap: true, disabled: [.snapCenter]) == nil)
    }

    @Test func tabsCloseOnPinchAndSnapOnSwipe() {
        #expect(resolve(.tab(isFullscreen: false), steps: [.pinchIn]) == .closeTab)
        #expect(resolve(.tab(isFullscreen: false), steps: [.left]) == .snap(.leftHalf))
        #expect(resolve(.tab(isFullscreen: false), steps: [.pinchIn], disabled: [.tabClose]) == nil)
    }

    @Test func fullScreenWindowsOnlyLeaveFullScreenOrClose() {
        #expect(resolve(.window(isFullscreen: true), steps: [.left]) == nil)
        #expect(resolve(.window(isFullscreen: true), steps: [.down]) == nil)
        #expect(resolve(.window(isFullscreen: true), steps: [.pinchOut]) == .toggleFullScreen)
        #expect(resolve(.window(isFullscreen: true), steps: [.pinchIn]) == .close)
        #expect(resolve(.window(isFullscreen: true), doubleTap: true) == nil)
    }

    @Test func dockIconGestures() {
        #expect(resolve(.app, steps: [.up]) == .restoreLastMinimized)
        #expect(resolve(.app, steps: [.down]) == .minimizeFrontWindow)
        #expect(resolve(.app, steps: [.pinchIn]) == .quitApp)
        #expect(resolve(.app, steps: [.left]) == nil)
        #expect(resolve(.app, steps: [.pinchOut]) == nil)
        #expect(resolve(.app, doubleTap: true) == nil)
    }

    @Test func menuBarGestures() {
        #expect(resolve(.menuBar, steps: [.left]) == .switchApp(forward: false))
        #expect(resolve(.menuBar, steps: [.right]) == .switchApp(forward: true))
        #expect(resolve(.menuBar, steps: [.down]) == .minimizeAllOnDisplay)
        #expect(resolve(.menuBar, steps: [.up]) == .restoreAllOnDisplay)
        #expect(resolve(.menuBar, steps: [.right], held: true) == .openSwitcher)
        #expect(resolve(.menuBar, steps: [.pinchIn]) == nil)
        #expect(resolve(.menuBar, doubleTap: true) == nil)
    }

    @Test func onlyAppSwitchingActsMidGesture() {
        #expect(WindowGestureCommand.switchApp(forward: true).isImmediate)
        #expect(!WindowGestureCommand.snap(.leftHalf).isImmediate)
        #expect(!WindowGestureCommand.minimizeFrontWindow.isImmediate)
    }
}
