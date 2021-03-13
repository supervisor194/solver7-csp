import Foundation

class HaltingStore<T> : Store  {

    typealias Item = T

    let original : AnyStore<T>

    public init(original: AnyStore<T>) {
        self.original = original
    }

    var max: Int {
        original.max
    }

    var state: StoreState {
        if isFull() {
            return StoreState.FULL
        }
        return StoreState.NONEMPTY
    }

    func isFull() -> Bool {
        count == max
    }

    func isEmpty() -> Bool {
        false
    }

    func putForNode(_ item: Item?) -> (Int, U: StoreNode?) {
        (-1, nil)
    }


    public var count: Int {
        get {
            let c = original.count
            if c == 0 {
                return 1
            } else {
                return c
            }
        }
    }

    public func put(_ item: T?) -> Int {
        // no puts allowed
        -1
    }

    public func get() -> T? {
        if original.count == 0 {
            return nil
        }
        return original.get()
    }

    func get(into: inout [Item?], upTo: Int) -> (Int, Int) {
        if original.count == 0 {
            into.append(nil)
            return (1,1)
        }
        return original.get(into: &into, upTo: upTo)
    }

    func clear() -> Int {
        original.clear()
    }

    func remove(_ item: Item?) -> Bool {
        false
    }


}
