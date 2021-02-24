import Foundation

public class NonSelectableChannel<T>: Channel {

    public typealias Item = T // todo: remove ?

    let capacity: Int
    let capacityMinus1: Int
    let capacityMinus2: Int

    let writeLock: Lock
    let readLock: Lock

    private let _lockType: LockType

    var s: AnyStore<T>

    public init(store: AnyStore<T>, lockType: LockType = LockType.NON_FAIR_LOCK) {
        s = store
        capacity = store.max
        capacityMinus1 = capacity - 1
        capacityMinus2 = capacity - 2

        _lockType = lockType

        switch lockType {
        case .FAIR_LOCK:
            writeLock = FairLock(maxThreads: 100)
            readLock = FairLock(maxThreads: 100)
        default:
            writeLock = NonFairLock(maxThreads: 100)
            readLock = NonFairLock(maxThreads: 100)
        }
    }

    public func getLockType() -> LockType {
        return _lockType
    }

    public func write(_ item: T?) {
        writeLock.lock();
        defer {
            writeLock.unlock()
        }
        let c = s.put(item)
        if c == 1 {
            do {
                readLock.lock()
                defer {
                    readLock.unlock()
                }
                readLock.doNotify()
            }
        }
        while s.count == capacity {
            ThreadContext.currentContext().down()
        }
    }


    public func read() -> T? {
        let o: T?
        let c: Int
        do {
            readLock.lock()
            defer {
                readLock.unlock()
            }
            while s.count == 0 {
                readLock.doWait()

            }
            o = s.get()
            c = s.count
            /*
            (o, scnt) = s.getWithCount()
            while scnt == -1 {
                readLock.doWait()
                (o, scnt) = s.getWithCount()
            }
             */
            if c > 0 {
                readLock.doNotify()
            }
        }
        if c >= capacityMinus1 {
            writeLock.reUp()
        }
        return o
    }

    public func read(into: inout [T?], upTo: Int) -> Void {
        let c: Int
        let r: Int
        do {
            readLock.lock()
            defer {
                readLock.unlock()
            }
            while s.count == 0 {
                readLock.doWait()
            }
            (c, r) = s.get(into: &into, upTo: upTo)
            if r > 0 {
                readLock.doNotify()
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
