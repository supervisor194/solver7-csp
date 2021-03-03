import Foundation
import Atomics

public class SingleValueStore<T: Equatable>: Store {
    public func get(into: inout [T?], upTo: Int) -> (Int, Int) {
        fatalError("need to implement")
    }

    public func putForNode(_ item: T?) -> (Int, U: StoreNode) {
        fatalError("putForNode(_:) has not been implemented")
    }

    var value: T?

    public init() {
    }

    public var max: Int {
        get {
            1
        }
    }

    private var _count = ManagedAtomic<Int>(0)

    public var count: Int {
        get {
            _count.load(ordering: .relaxed)
        }
    }

    public func put(_ o: T?) -> Int {
        value = o
        return _count.wrappingIncrementThenLoad(ordering: .relaxed)
    }

    public func get() -> T? {
        let o = value
        value = nil
        _count.wrappingDecrement(ordering: .relaxed)
        return o
    }

    public var state: StoreState {
        get {
            _count.load(ordering: .relaxed) == 0 ? StoreState.EMPTY: StoreState.FULL
        }
    }

    public func isFull() -> Bool {
        _count.load(ordering: .relaxed) != 0
    }

    public func isEmpty() -> Bool {
        _count.load(ordering: .relaxed) == 0
    }

    public func clear() -> Int {
        if _count.compareExchange(expected: 1, desired: 0, ordering: .relaxed).exchanged {
            value = nil
            return 1
        }
        return 0
    }

    public func remove(_ item: T?) -> Bool {
        if item == value && _count.load(ordering: .relaxed) != 0 {
            value = nil
            _count.store(0, ordering: .relaxed)
            return true
        }
        return false
    }


}