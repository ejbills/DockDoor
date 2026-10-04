@testable import DockDoor
import Testing

struct WindowTitlePresentationTests {
    @Test func hoveringTitleReservesSpaceBeforeTheCardIsHighlighted() {
        let presentation = WindowTitlePresentation.resolve(
            title: "Document",
            showWindowTitle: true,
            visibility: .whenHoveringPreview,
            isHighlighted: false
        )

        #expect(!presentation.isVisible)
        #expect(presentation.reservesSpace)
    }

    @Test func alwaysVisibleTitleIsVisibleAndReservesSpace() {
        let presentation = WindowTitlePresentation.resolve(
            title: "Document",
            showWindowTitle: true,
            visibility: .alwaysVisible,
            isHighlighted: false
        )

        #expect(presentation.isVisible)
        #expect(presentation.reservesSpace)
    }

    @Test func hoveringTitleBecomesVisibleWithoutChangingItsReservedSpace() {
        let presentation = WindowTitlePresentation.resolve(
            title: "Document",
            showWindowTitle: true,
            visibility: .whenHoveringPreview,
            isHighlighted: true
        )

        #expect(presentation.isVisible)
        #expect(presentation.reservesSpace)
    }

    @Test func missingOrDisabledTitlesDoNotReserveSpace() {
        let missingTitle = WindowTitlePresentation.resolve(
            title: nil,
            showWindowTitle: true,
            visibility: .whenHoveringPreview,
            isHighlighted: false
        )
        let disabledTitle = WindowTitlePresentation.resolve(
            title: "Document",
            showWindowTitle: false,
            visibility: .whenHoveringPreview,
            isHighlighted: false
        )

        #expect(!missingTitle.reservesSpace)
        #expect(!disabledTitle.reservesSpace)
    }
}
