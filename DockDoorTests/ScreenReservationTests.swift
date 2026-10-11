import CoreGraphics
@testable import DockDoor
import Testing

struct ScreenReservationTests {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)

    private func reserve(_ edge: ScreenReservationEdge, _ thickness: CGFloat) -> ScreenReservation {
        ScreenReservation(edge: edge, thickness: thickness, display: ScreenReservation.allDisplays)
    }

    @Test func bottomReservationRaisesTheFloor() {
        let frame = ScreenReservation.usableFrame(visibleFrame: visible, screenFrame: screen, reservations: [reserve(.bottom, 80)])
        #expect(frame == CGRect(x: 0, y: 80, width: 1440, height: 795))
    }

    @Test func sideReservationsNarrowTheFrame() {
        let left = ScreenReservation.usableFrame(visibleFrame: visible, screenFrame: screen, reservations: [reserve(.left, 70)])
        let right = ScreenReservation.usableFrame(visibleFrame: visible, screenFrame: screen, reservations: [reserve(.right, 70)])
        #expect(left == CGRect(x: 70, y: 0, width: 1370, height: 875))
        #expect(right == CGRect(x: 0, y: 0, width: 1370, height: 875))
    }

    @Test func topReservationStartsBelowTheMenuBar() {
        let frame = ScreenReservation.usableFrame(visibleFrame: visible, screenFrame: screen, reservations: [reserve(.top, 60)])
        #expect(frame == CGRect(x: 0, y: 0, width: 1440, height: 815))
    }

    @Test func reservationDoesNotStackOnTheSystemDock() {
        let withDock = CGRect(x: 0, y: 90, width: 1440, height: 785)
        let frame = ScreenReservation.usableFrame(visibleFrame: withDock, screenFrame: screen, reservations: [reserve(.bottom, 80)])
        #expect(frame == withDock)
    }

    @Test func multipleEdgesCombine() {
        let frame = ScreenReservation.usableFrame(visibleFrame: visible, screenFrame: screen, reservations: [reserve(.bottom, 80), reserve(.left, 60)])
        #expect(frame == CGRect(x: 60, y: 80, width: 1380, height: 795))
    }

    @Test func hugeReservationsAreCapped() {
        let frame = ScreenReservation.usableFrame(visibleFrame: visible, screenFrame: screen, reservations: [reserve(.bottom, 5000)])
        #expect(frame == CGRect(x: 0, y: 360, width: 1440, height: 515))
    }

    @Test func offAndEmptyReservationsChangeNothing() {
        let frame = ScreenReservation.usableFrame(visibleFrame: visible, screenFrame: screen, reservations: [reserve(.none, 80), reserve(.left, 0)])
        #expect(frame == visible)
    }

    @Test func parsingAcceptsEdgesAndRejectsGarbage() {
        #expect(ScreenReservation.parse(edge: "Bottom", thickness: 72, display: nil) == reserve(.bottom, 72))
        #expect(ScreenReservation.parse(edge: "none", thickness: nil, display: "main")?.edge == ScreenReservationEdge.none)
        #expect(ScreenReservation.parse(edge: "sideways", thickness: 72, display: nil) == nil)
        #expect(ScreenReservation.parse(edge: "left", thickness: -4, display: nil) == nil)
        #expect(ScreenReservation.parse(edge: "left", thickness: .infinity, display: nil) == nil)
    }
}
