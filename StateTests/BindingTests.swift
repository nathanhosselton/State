import XCTest
@testable import State

class BindingTests: XCTestCase {

    func test_SentValueIsReceived() {
        let x = expectation(description: "Sent value is received in listener handler")

        let binding = Binding<Void>()
        binding.observe {
            x.fulfill()
        }
        binding.emit(())

        wait(for: [x], timeout: 0.1)
    }

    func test_ObservedValueMatchesSentValue() {
        let binding = Binding<String>()
        let foo = "foo"

        binding.observe { (bar) in
            XCTAssert(bar == foo)
        }

        binding.emit(foo)
    }

    func test_InitialValueIsReceived() {
        let x = expectation(description: "Initial value is received in listener handler")

        _ = Binding(value: "foo") { _ in
            x.fulfill()
        }

        wait(for: [x], timeout: 0.1)
    }

    func test_MappedBindingReceivesUpdatesFromSourceBinding() {
        let x = expectation(description: "`map`d binding is notified when source binding receives new value")

        let binding = Binding<Void>()
        let mapped = binding.map {
            x.fulfill()
        }
        binding.emit(())

        _ = mapped //Keep `mapped` alive but silence the unused value warning
        wait(for: [x], timeout: 0.1)
    }

    func test_MappedBindingUpdatesItsOwnObservers() {
        let x = expectation(description: "`map`d binding updates its own observers")

        let binding = Binding<Void>()
        let mapped = binding.map {}
        mapped.observe {
            x.fulfill()
        }
        binding.emit(())

        wait(for: [x], timeout: 0.1)
    }

    func test_MappedBindingTransformIsApplied() {
        let x = expectation(description: "`map`d binding's transform is applied to the source binding's emitted value")

        let binding = Binding<Int>()
        let mapped = binding.map {
            $0 + 1
        }
        mapped.observe {
            XCTAssert($0 == 2)
            x.fulfill()
        }
        binding.emit(1)

        wait(for: [x], timeout: 0.1)
    }

    func test_FlatMappedBindingTransformIsApplied() {
        //Note: `flatMap` returns `map` and therefore shares its test coverage
        let x = expectation(description: "`flatMap`d binding's transform is applied to the source binding's emitted value")

        let binding = Binding<[Int]>()
        let mapped = binding.flatMap {
            $0 + 1
        }
        mapped.observe {
            $0.forEach { XCTAssert($0 == 2) }
            x.fulfill()
        }
        binding.emit([1, 1, 1])

        wait(for: [x], timeout: 0.1)
    }

    func test_FirstBindingPredicateIsApplied() {
        //Note: `first` returns `map` and uses `Sequence.first` and therefore shares test coverage from both
        let x = expectation(description: "`first` binding's predicate is applied to the source binding's emitted value")

        let predicate: (Int) -> Bool = { $0 > 1 }
        let binding = Binding<[Int]>()
        let first = binding.first(where: predicate)
        first.observe {
            guard let value = $0 else { XCTFail(); return x.fulfill() }
            XCTAssert(predicate(value))
            x.fulfill()
        }
        binding.emit([0, 1, 1, 2, 3])

        wait(for: [x], timeout: 0.1)
    }

    func test_UnwrappedBindingProvidesUnwrappedValue() {
        //Note: `unwrapped` returns `map` and therefore shares its test coverage
        let x = expectation(description: "unwrapped")

        let binding = Binding<Int?>()
        let unwrapped = binding.unwrapped(defaultValue: 1)
        unwrapped.observe {
            XCTAssert($0 == 0)
            x.fulfill()
        }
        binding.emit(0)

        wait(for: [x], timeout: 0.1)
    }

    func test_UnwrappedBindingProvidesDefaultValue() {
        //Note: `unwrapped` returns `map` and therefore shares its test coverage
        let x = expectation(description: "unwrapped")

        let binding = Binding<Int?>()
        let unwrapped = binding.unwrapped(defaultValue: 1)
        unwrapped.observe {
            XCTAssert($0 == 1)
            x.fulfill()
        }
        binding.emit(.none)

        wait(for: [x], timeout: 0.1)
    }

    func test_MultipleObserversAreNotified() {
        let x = expectation(description: "All observers are notified when a new value is emitted.")
        x.expectedFulfillmentCount = 5

        let binding = Binding<Void>()
        let observer: () -> Void = {
            x.fulfill()
        }
        binding.observe(with: observer)
        binding.observe(with: observer)
        binding.observe(with: observer)
        binding.observe(with: observer)
        binding.observe(with: observer)
        binding.emit(())

        XCTAssert(binding.observerCount == x.expectedFulfillmentCount)
        wait(for: [x], timeout: 0.1)
    }

    func test_ExcessiveObserversAreNotified() {
        let x = expectation(description: "All observers are notified when a new value is emitted.")
        x.expectedFulfillmentCount = 100

        let binding = Binding<Void>()
        let observer: () -> Void = {
            x.fulfill()
        }
        for _ in 0..<x.expectedFulfillmentCount {
            binding.observe(with: observer)
        }
        binding.emit(())

        wait(for: [x], timeout: 0.1)
    }

    func test_ExtremeObserversAreNotified() {
        let x = expectation(description: "All observers are notified when a new value is emitted.")
        x.expectedFulfillmentCount = 1000

        let binding = Binding<Void>()
        let observer: () -> Void = {
            x.fulfill()
        }
        for _ in 0..<x.expectedFulfillmentCount {
            binding.observe(with: observer)
        }
        binding.emit(())

        wait(for: [x], timeout: 0.1)
    }

    func test_MultipleObserversAreCalledSequentially() {
        let x = expectation(description: "All observers are notified in the order they were added.")
        var track = 0

        let binding = Binding<Void>()
        binding.observe {
            XCTAssert(track == 0)
            track += 1
        }
        binding.observe {
            XCTAssert(track == 1)
            track += 1
        }
        binding.observe {
            XCTAssert(track == 2)
            track += 1
        }
        binding.observe {
            XCTAssert(track == 3)
            track += 1
        }
        binding.observe {
            XCTAssert(track == 4)
            x.fulfill()
        }
        binding.emit(())

        wait(for: [x], timeout: 0.1)
    }

    func test_ChainedMapsAreNotified() {
        let x = expectation(description: "All observers are notified along a chain of binding transforms")
        x.expectedFulfillmentCount = 5

        let binding = Binding<Void>()
        let map1 = binding.map { x.fulfill() }
        let map2 = map1.map { x.fulfill() }
        let map3 = map2.map { x.fulfill() }
        let map4 = map3.map { x.fulfill() }
        let map5 = map4.map { x.fulfill() }
        binding.emit(())

        _ = map5; //Keep `map5` alive but silence the unused value warning
        wait(for: [x], timeout: 0.1)
    }

    func test_Performance() {
        measure(test_ExtremeObserversAreNotified)
    }

}
