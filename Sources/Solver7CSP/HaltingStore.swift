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

    /**
     HaltingStore is never full
     - Returns:
     */
    func isFull() -> Bool {
        false
    }

    func isEmpty() -> Bool {
        false
    }

    /*
    func putForNode(_ item: Item?) -> (Int, U: StoreNode?) {
        (-1, nil)
    }
     */


    public var count: Int {
        get {
            original.count
        }
    }

    public func put(_ item: T?) throws -> Int  {
        throw ChannelError.closed(msg: "Channel has been closed to put()")
    }

    public func get() throws -> T? {
        if original.count == 0 {
            throw ChannelError.closed(msg: "Channel has been closed for get()")
        }
        return try original.get()
    }

    func get(into: inout [Item?], upTo: Int) throws -> (Int, Int) {
        if original.count == 0 {
            throw ChannelError.closed(msg: "Channel has been closed for get()")
        }
        return try original.get(into: &into, upTo: upTo)
    }

    func clear() -> Int {
        original.clear()
    }

    func remove(_ item: Item?) -> Bool {
        false
    }


}
