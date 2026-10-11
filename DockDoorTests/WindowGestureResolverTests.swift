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
        #expect(resolve(steps: [.left]) == .window(.fillLeftHalf))
        #expect(resolve(steps: [.right]) == .window(.fillRightHalf))
        #expect(resolve(steps: [.right, .down]) == .window(.fillBottomRightQuarter))
        #expect(resolve(steps: [.down, .right]) == .window(.fillBottomRightQuarter))
        #expect(resolve(steps: [.up, .left]) == .window(.fillTopLeftQuarter))
        #expect(resolve(steps: [.left, .down]) == .window(.fillBottomLeftQuarter))
        #expect(resolve(steps: [.right, .up]) == .window(.fillTopRightQuarter))
    }

    @Test func verticalSwipesFillAndMinimize() {
        #expect(resolve(steps: [.up]) == .window(.maximize))
        #expect(resolve(steps: [.down]) == .window(.minimize))
        #expect(resolve(steps: [.up, .up]) == nil)
        #expect(resolve(steps: [.right, .right]) == nil)
    }

    @Test func holdingDoesNotChangeTitleBarSwipes() {
        #expect(resolve(steps: [.right], held: true) == .window(.fillRightHalf))
        #expect(resolve(held: true) == nil)
    }

    @Test func disabledGesturesResolveToNothing() {
        #expect(resolve(steps: [.left], disabled: [.snapHalves]) == nil)
        #expect(resolve(steps: [.pinchIn], disabled: [.windowClose]) == nil)
        #expect(resolve(.app, steps: [.pinchIn], disabled: [.appQuit]) == nil)
    }

    @Test func pinchesCloseAndToggleFullScreen() {
        #expect(resolve(steps: [.pinchIn]) == .window(.close))
        #expect(resolve(steps: [.pinchIn, .pinchIn]) == .window(.close))
        #expect(resolve(steps: [.pinchOut]) == .window(.toggleFullScreen))
        #expect(resolve(steps: [.pinchOut, .pinchOut]) == .window(.toggleFullScreen))
    }

    @Test func doubleTapCenters() {
        #expect(resolve(doubleTap: true) == .window(.center))
        #expect(resolve(doubleTap: true, disabled: [.snapCenter]) == nil)
    }

    @Test func tabsCloseOnPinchAndSnapOnSwipe() {
        #expect(resolve(.tab(isFullscreen: false), steps: [.pinchIn]) == .closeTab)
        #expect(resolve(.tab(isFullscreen: false), steps: [.left]) == .window(.fillLeftHalf))
        #expect(resolve(.tab(isFullscreen: false), steps: [.pinchIn], disabled: [.tabClose]) == nil)
    }

    @Test func fullScreenWindowsOnlyLeaveFullScreenOrClose() {
        #expect(resolve(.window(isFullscreen: true), steps: [.left]) == nil)
        #expect(resolve(.window(isFullscreen: true), steps: [.down]) == nil)
        #expect(resolve(.window(isFullscreen: true), steps: [.pinchOut]) == .window(.toggleFullScreen))
        #expect(resolve(.window(isFullscreen: true), steps: [.pinchIn]) == .window(.close))
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
        #expect(!WindowGestureCommand.window(.fillLeftHalf).isImmediate)
        #expect(!WindowGestureCommand.minimizeFrontWindow.isImmediate)
    }
}
