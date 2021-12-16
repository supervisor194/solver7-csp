import Foundation

/**
 Note: A Store is in general not thread safe until wrapped by a Channel. The Channel must watch the
 Store.count and provide the proper synchronization of the get/put of values with its writer/reader locks.
 */

public enum StoreState {
    case EMPTY, FULL, NONEMPTY
}

public protocol StoreNode: class {
}

public protocol Store: class {

    associatedtype Item

    var max: Int { get }

    var count: Int { get }

    var state: StoreState { get }

    func isFull() -> Bool

    func isEmpty() -> Bool

    func put(_ item: Item?) throws -> Int

    // func putForNode(_ item: Item?) -> (Int, U: StoreNode?)

    func get() throws -> Item?

    func get(into: inout [Item?], upTo: Int) throws -> (Int, Int)

    func clear() -> Int

    func remove(_ item: Item?) -> Bool

}

private extension Store {

    func getMax() -> Int {
        max
    }

    func getCount() -> Int {
        count
    }

    func getState() -> StoreState {
        state
    }

}


public class AnyStore<T>: Store {

    private let _getMax: () -> Int

    public var max: Int {
        get {
            _getMax()
        }
    }

    private let _getCount: () -> Int
    public var count: Int {
        get {
            _getCount()
        }
    }

    private let _getState: () -> StoreState

    public var state: StoreState {
        get {
            _getState()
        }
    }

    private let _isFull: () -> Bool

    public func isFull() -> Bool {
        _isFull()
    }

    private let _isEmpty: () -> Bool

    public func isEmpty() -> Bool {
        _isEmpty()
    }

    private let _put: (_ item: T?) throws -> Int

    public func put(_ item: T?) throws -> Int {
        try _put(item)
    }

    /*
    private let _putForNode: (_ item: T?) -> (Int, U: StoreNode?)

    public func putForNode(_ item: T?) -> (Int, U: StoreNode?) {
        _putForNode(item)
    }
     */

    private let _get: () throws -> T?

    public func get() throws -> T? {
        try _get()
    }

    private let _getAvailableUpTo: (inout [T?], Int) throws -> (Int, Int)

    public func get(into: inout [T?], upTo: Int) throws -> (Int, Int) {
        try _getAvailableUpTo(&into, upTo)
    }

    private let _clear: () -> Int

    public func clear() -> Int {
        _clear()
    }

    private let _remove: (_ item: T?) -> Bool

    public func remove(_ item: T?) -> Bool {
        _remove(item)
    }

    public init<S: Store>(_ s: S) where S.Item == T {
        _getMax = s.getMax
        _getCount = s.getCount
        _getState = s.getState
        _isFull = s.isFull
        _isEmpty = s.isEmpty
        _put = s.put
        // _putForNode = s.putForNode
        _get = s.get
        _getAvailableUpTo = s.get
        _clear = s.clear
        _remove = s.remove
    }


}

