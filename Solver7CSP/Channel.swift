import Foundation


public enum LockType {
    case FAIR_LOCK
    case NON_FAIR_LOCK
}

public protocol Channel: ReadableChannel, WritableChannel {

    func getLockType() -> LockType

}

public class AnyChannel<T>: Channel {
    public typealias Item = T // todo: remove ???

    private let _getLockType: () -> LockType

    public func getLockType() -> LockType {
        _getLockType()
    }

    private let _read: () -> T?

    private let _readAvailable: (inout [T?], Int) -> Void

    public func read() -> T? {
        _read()
    }

    public func read(into: inout [T?], upTo: Int) {
        _readAvailable(&into, upTo)
    }

    private let _numAvailable: () -> Int

    public func numAvailable() -> Int {
        _numAvailable()
    }

    private let _write: (_ item: T?) -> Void

    public func write(_ item: T?) -> Void {
        _write(item)
    }

    public init<C: Channel>(_ c: C) where C.Item == T {
        _getLockType = c.getLockType
        _read = c.read
        _readAvailable = c.read
        _numAvailable = c.numAvailable
        _write = c.write
    }

}

