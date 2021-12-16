import Foundation

public class NonSelectableChannel<T>: Channel {

    public typealias Item = T

    let id: String
    let capacity: Int
    let capacityMinus1: Int
    let capacityMinus2: Int

    let writeLock: Lock
    let readLock: Lock
    let notEmpty: Condition

    var closed: Bool = false

    var s: AnyStore<T>

    public init(id: String? = nil, store: AnyStore<T>, writeLock: Lock = NonFairLock(10), readLock: Lock = NonFairLock(10)) {
        if let theId = id {
            self.id = theId
        } else {
            self.id = UUID.init().uuidString
        }
        s = store
        capacity = store.max
        capacityMinus1 = capacity - 1
        capacityMinus2 = capacity - 2
        self.writeLock = writeLock
        self.readLock = readLock
        notEmpty = readLock.createCondition()
    }

    public func getId() -> String {
        id
    }

    public func isEmpty() -> Bool {
        s.isEmpty()
    }

    public func isClosed() -> Bool {
        closed
    }

    public func close() {
        readLock.lock()
        defer {
            readLock.unlock()
        }
        s = AnyStore<T>(HaltingStore(original: s))
        closed = true
        writeLock.reUp()
        notEmpty.doNotifyAll()
    }

    public func write(_ item: T?) throws {
        writeLock.lock();
        defer {
            writeLock.unlock()
        }
        let c = try s.put(item)
        if c == 1 {
            do {
                readLock.lock()
                defer {
                    readLock.unlock()
                }
                notEmpty.doNotify()
            }
        }
        while s.isFull() {
            ThreadContext.currentContext().down()
        }
    }

    public func read() throws -> T? {
        let o: T?
        let c: Int
        do {
            readLock.lock()
            defer {
                readLock.unlock()
            }
            while s.isEmpty() {
                notEmpty.doWait()
            }
            o = try s.get()
            c = s.count
            if c > 0 {
                notEmpty.doNotify()
            }
        }
        if c >= capacityMinus1 {
            writeLock.reUp()
        }
        return o
    }

    public func read(into: inout [T?], upTo: Int) throws -> Void {
        let c: Int
        let r: Int
        do {
            readLock.lock()
            defer {
                readLock.unlock()
            }
            while s.isEmpty() {
                notEmpty.doWait()
            }
            (c, r) = try s.get(into: &into, upTo: upTo)
            if r > 0 {
                notEmpty.doNotify()
            }
        }
        if c >= capacity - upTo {
            writeLock.reUp()
        }
    }

    public func numAvailable() -> Int {
        s.count
    }

}
