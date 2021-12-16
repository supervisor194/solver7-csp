import Foundation

public enum ChannelError: Error {
    case closed(msg: String)
}

public protocol Closeable {
    func getId() -> String
    func close()
    func isEmpty() -> Bool
    func isClosed() -> Bool
}

public protocol ReadableChannel {
    associatedtype Item
    func read() throws -> Item?
    func read(into: inout [Item?], upTo: Int) throws -> Void
    func numAvailable() -> Int
}

public protocol WritableChannel {
    associatedtype Item
    func write(_ item: Item?) throws
}


public protocol Channel: ReadableChannel, WritableChannel, Closeable {
}

public class AnyChannel<T>: Channel {

    public typealias Item = T

    private let _id : () -> String

    public func getId() -> String {
        _id()
    }

    private let _read: () throws -> T?

    private let _readAvailable: (inout [T?], Int) throws -> Void

    public func read() throws -> T? {
        try _read()
    }

    public func read(into: inout [T?], upTo: Int) throws {
        try _readAvailable(&into, upTo)
    }

    private let _numAvailable: () -> Int

    public func numAvailable() -> Int {
        _numAvailable()
    }

    private let _write: (_ item: T?) throws -> Void

    public func write(_ item: T?) throws -> Void {
        try _write(item)
    }

    private let _close: () -> Void

    public func close() -> Void {
        _close()
    }

    private let _isEmpty: () -> Bool

    public func isEmpty() -> Bool  {
        _isEmpty()
    }

    private let _isClosed: () -> Bool

    public func isClosed() -> Bool {
        _isClosed()
    }

    private let _isSelectable: Bool

    public func isSelectable() -> Bool {
        _isSelectable
    }

    private let _selectable: SelectableChannel<T>?

    public var selectable: SelectableChannel<T>? { get {
        _selectable
    }}

    public init<C: Channel>(_ c: C) where C.Item == T {
        _isSelectable = c is Selectable
        if _isSelectable {
            _selectable = (c as! SelectableChannel<T>)
        } else {
            _selectable = nil
        }
        _id = c.getId
        _read = c.read
        _readAvailable = c.read
        _numAvailable = c.numAvailable
        _write = c.write
        _close = c.close
        _isEmpty = c.isEmpty
        _isClosed = c.isClosed
    }

}

