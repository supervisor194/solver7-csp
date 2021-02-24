import Foundation

class SingleValueStore<T: Equatable>: Store {
    func get(into: inout [T?], upTo: Int) -> (Int, Int) {
        fatalError("need to implement")
    }

    func putForNode(_ item: T?) -> (Int, U: StoreNode) {
        fatalError("putForNode(_:) has not been implemented")
    }

    func getWithCount() -> (T?, Int) {
        fatalError("getWithCount() has not been implemented")
    }

    var value: T?

    init() {

    }

    var max: Int {
        get {
            1
        }
    }

    var count: Int {
        get {
            value != nil ? 1 : 0
        }
    }

    var count2: Int {
        get {
            value != nil ? 1 : 0
        }
    }

    public func put(_ o: T?) -> Int {
        value = o
        return 1
    }

    public func get() -> T? {
        let o = value
        value = nil
        return o
    }

    var state: StoreState {
        get {
            value != nil ? StoreState.FULL : StoreState.EMPTY
        }
    }

    public func isFull() -> Bool {
        value != nil
    }

    public func isEmpty() -> Bool {
        value == nil
    }

    public func clear() -> Int {
        if value == nil {
            return 0
        }
        value = nil
        return 1
    }

    public func remove(_ item: T?) -> Bool {
        if let i = item {
            if i == value {
                value = nil
                return true
            }
        }
        return false
    }


}