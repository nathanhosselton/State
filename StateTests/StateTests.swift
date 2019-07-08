import XCTest
@testable import State

class StateTests: XCTestCase {

    func test_InitializedWithValue() {
        let value = "foo"
        let state = State(initialValue: value)
        XCTAssert(state.snapshot == value)
    }

    func test_ValueIsUpdatedViaBinding() {
        let value = "foo"
        let state = State(initialValue: "")
        state.binding.emit(value)
        XCTAssert(state.snapshot == value)
    }

    func test_CombinedStateCountMatchesInputStateCount() {
        let state1 = State(initialValue: ())
        let state2 = State(initialValue: ())
        let state3 = State(initialValue: ())
        let combined = State.combined([state1, state2, state3])
        XCTAssert(combined.snapshot.count == 3)
    }

    func test_CombinedReceivesUpdatesFromAllSourceBindings() {
        let x = expectation(description: "Combined receives updates from all source bindings")
        x.expectedFulfillmentCount = 3

        let state1 = State(initialValue: ())
        let state2 = State(initialValue: ())
        let state3 = State(initialValue: ())
        let combined = State.combined([state1, state2, state3])
        combined.binding.observe { _ in
            x.fulfill()
        }
        state1.binding.emit(())
        state2.binding.emit(())
        state3.binding.emit(())

        wait(for: [x], timeout: 0.1)
    }

}
