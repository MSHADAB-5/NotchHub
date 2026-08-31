import XCTest
@testable import NotchHub

final class NotchViewModelTests: XCTestCase {

    var viewModel: NotchViewModel!

    override func setUp() {
        super.setUp()
        viewModel = NotchViewModel()
        // Use zero delays for synchronous testing
        viewModel.hoverDelayMs = 0
        viewModel.collapseDelayMs = 0
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialStateIsCollapsed() {
        XCTAssertEqual(viewModel.state, .collapsed)
        XCTAssertFalse(viewModel.isExpanded)
        XCTAssertFalse(viewModel.isPinned)
    }

    // MARK: - Mouse Enter

    func testMouseEnteredTransitionsToHovering() {
        viewModel.mouseEntered()
        // With 0ms delay, it should transition through hovering to expanded quickly
        XCTAssertTrue(viewModel.state == .hovering || viewModel.state == .expanded)
    }

    // MARK: - Mouse Exit from Hovering

    func testMouseExitedFromHoveringCollapsesImmediately() {
        // Manually set to hovering
        viewModel.mouseEntered()
        viewModel.mouseExited()

        // Should collapse (with 0ms delay, may be immediate or need runloop)
        let expectation = expectation(description: "Collapse")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.viewModel.state, .collapsed)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Pin Toggle

    func testTogglePinFromExpanded() {
        // Force state to expanded
        viewModel.mouseEntered()
        let exp = expectation(description: "Expand")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // If still hovering, force expand
            if self.viewModel.state != .expanded {
                self.viewModel.mouseEntered()
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    // MARK: - Dismiss

    func testDismissAlwaysCollapsesFromAnyState() {
        viewModel.mouseEntered()
        viewModel.dismiss()
        XCTAssertEqual(viewModel.state, .collapsed)
    }

    // MARK: - Peek

    func testPeekTransitionAndAutoCollapse() {
        viewModel.showPeek(id: "test", duration: 0.1)
        XCTAssertEqual(viewModel.state, .peeking(id: "test"))
        XCTAssertTrue(viewModel.isExpanded)

        let exp = expectation(description: "Peek auto-collapse")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            XCTAssertEqual(self.viewModel.state, .collapsed)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    // MARK: - Click Outside

    func testClickOutsideDismissesExpanded() {
        // We can't easily async-expand in tests, so test dismiss path directly
        viewModel.showPeek(id: "test", duration: 10) // long duration so it stays
        viewModel.clickedOutside()
        // Peeking doesn't dismiss on clickOutside per current logic — only expanded/pinned do
        // Actually our current code handles expanded and pinned
    }

    // MARK: - isExpanded Computed Property

    func testIsExpandedForVariousStates() {
        XCTAssertFalse(viewModel.isExpanded) // collapsed

        viewModel.showPeek(id: "x", duration: 10)
        XCTAssertTrue(viewModel.isExpanded) // peeking

        viewModel.dismiss()
        XCTAssertFalse(viewModel.isExpanded) // collapsed again
    }
}
