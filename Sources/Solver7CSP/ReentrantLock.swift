import Foundation
import Atomics

typealias NodePtr = UnsafeMutablePointer<WaitQNode>

open class ReentrantLock: Lock {

    static let UNLOCKED: Int = 0
    static let LOCKED: Int = 1

    static let WAITER_INITIAL: Int = 0
    static let WAITER_NEED_SIGNAL: Int = 1
    static let WAITER_SIGNALED: Int = 2

    internal var lockingTc: ThreadContext? = nil
    internal let state = ManagedAtomic<Int>(0)

    // Build a non locking queue with tail and head.
    // The tail is managed via a pointer to a Node to enable atomic modifications
    private let waitQTailPtr: UnsafeAtomic<NodePtr>
    private var waitQHeadPtr: UnsafeAtomic<NodePtr>

    private let waiterQ: LinkedListQueue<TCNode>
    private let waiterPool: LinkedListQueue<TCNode>

    let maxThreads: Int

    public init(maxThreads: Int) {
        self.maxThreads = maxThreads
        let firstNode = WaitQNode(status: ReentrantLock.UNLOCKED)
        let firstNodePtr = UnsafeMutablePointer<WaitQNode>.allocate(capacity: 1)
        firstNodePtr.initialize(to: firstNode)
        var node = firstNode
        for _ in 1...maxThreads {
            let newNode = WaitQNode(status: ReentrantLock.UNLOCKED)
            let newNodePtr = UnsafeMutablePointer<WaitQNode>.allocate(capacity: 1)
            newNodePtr.initialize(to: newNode)
            node._nextPtr = newNodePtr
            node = newNode
        }
        node._nextPtr = firstNodePtr

        waitQTailPtr = UnsafeAtomic<NodePtr>.create(firstNodePtr)
        waitQHeadPtr = UnsafeAtomic<NodePtr>.create(firstNodePtr)

        waiterQ = LinkedListQueue<TCNode>(max: maxThreads)
        waiterPool = LinkedListQueue<TCNode>(max: maxThreads)
        for _ in 1...maxThreads {
            waiterPool.put(TCNode(status: ReentrantLock.WAITER_INITIAL))
        }
    }

    public func lock() {
        print("subclasses need to implement")
    }

    func schedule(_ tc: ThreadContext) -> Void {
        var tailPtr: NodePtr
        var tail: WaitQNode
        repeat {
            tailPtr = waitQTailPtr.load(ordering: .relaxed)
            tail = tailPtr.pointee
        } while !waitQTailPtr.compareExchange(expected: tailPtr, desired: tail._nextPtr!, ordering: .relaxed).exchanged;
        tail._tc = tc
        while tail !== waitQHeadPtr.load(ordering: .relaxed).pointee {
            if !tail.compareAndSetStatus(expectedStatus: ReentrantLock.WAITER_INITIAL, desiredStatus: ReentrantLock.WAITER_NEED_SIGNAL) {
                tc.down()
            }
        }
        // tail is/was  the waitQHead
        while !state.compareExchange(expected: ReentrantLock.UNLOCKED, desired: ReentrantLock.LOCKED, ordering: .relaxed).exchanged {
            if !tail.compareAndSetStatus(expectedStatus: ReentrantLock.WAITER_INITIAL, desiredStatus: ReentrantLock.WAITER_NEED_SIGNAL) {
                tc.down()
            }
        }
        tail.setStatus(status: ReentrantLock.WAITER_INITIAL)
        tail._tc = nil
        waitQHeadPtr.store(tail._nextPtr!, ordering: .relaxed)
    }

    public func unlock() -> Void {
        if ThreadContext.currentContext() !== lockingTc {
            fatalError("can't unlock(), we don't own the lock!!!")
        }
        lockingTc = nil
        state.store(ReentrantLock.UNLOCKED, ordering: .relaxed)
        let waitQHead = waitQHeadPtr.load(ordering: .relaxed).pointee
        if let tc = waitQHead._tc {
            if waitQHead.compareAndSetStatus(expectedStatus: ReentrantLock.WAITER_NEED_SIGNAL, desiredStatus: ReentrantLock.WAITER_INITIAL) {
                tc.up()
            }
        }
    }

    public func doWait() -> Void {
        let waiter = waiterPool.get()!
        waiter._tc = ThreadContext.currentContext()
        waiter.setStatus(status: ReentrantLock.WAITER_INITIAL)
        waiterQ.put(waiter)
        unlock()
        if waiter.compareAndSetStatus(expectedStatus: ReentrantLock.WAITER_INITIAL, desiredStatus: ReentrantLock.WAITER_NEED_SIGNAL) {
            while waiter.getStatus() == ReentrantLock.WAITER_NEED_SIGNAL {
                waiter._tc!.down()
            }
        }
        lock()
        waiter._tc = nil
        if waiter.getStatus() != ReentrantLock.WAITER_SIGNALED {
            print("not signalled...")
            if waiterQ.remove(waiter) {
                print("removed waiter leaving doWait()")
            }
        }
        waiterPool.put(waiter)
    }

    // must have the lock
    public func doWait(_ timeoutAt: inout timespec) {
        let waiter = waiterPool.get()!
        waiter._tc = ThreadContext.currentContext()
        waiter.setStatus(status: ReentrantLock.WAITER_INITIAL)
        waiterQ.put(waiter)
        // releasing the lock
        unlock()
        if waiter.compareAndSetStatus(expectedStatus: ReentrantLock.WAITER_INITIAL, desiredStatus: ReentrantLock.WAITER_NEED_SIGNAL) {
            while waiter.exchangeStatus(status: ReentrantLock.WAITER_NEED_SIGNAL) == ReentrantLock.WAITER_NEED_SIGNAL
                          && !TimeoutState.expired(timeoutAt) {
                waiter._tc?.down(&timeoutAt)
            }
        }
        lock()
        // we now have the lock again
        waiter._tc = nil
        if waiter.getStatus() != ReentrantLock.WAITER_SIGNALED {
            waiterQ.remove(waiter)
        }
        waiterPool.put(waiter)
    }

    // must have the lock to doNotify()
    public func doNotify() {
        if !waiterQ.isEmpty() {
            let head = waiterQ.get()!
            if head.exchangeStatus(status: ReentrantLock.WAITER_SIGNALED) == ReentrantLock.WAITER_NEED_SIGNAL {
                // print("w: \(Unmanaged.passUnretained(head).toOpaque()) up: \(head._tc!.name)")
                head._tc?.up()
            }
        }
    }

    public func reUp() -> Void {
        if let ltc = lockingTc {
            ltc.up()
        }
    }

}


class TCNode: Equatable {

    let _status: ManagedAtomic<Int>

    var _tc: ThreadContext? = nil

    init(status: Int) {
        _status = ManagedAtomic<Int>(status)
    }

    public func setStatus(status: Int) {
        _status.store(status, ordering: .relaxed)
    }

    public func compareAndSetStatus(expectedStatus: Int, desiredStatus: Int) -> Bool {
        _status.compareExchange(expected: expectedStatus, desired: desiredStatus, ordering: .acquiring).exchanged
    }

    public func exchangeStatus(status: Int) -> Int {
        _status.exchange(status, ordering: .releasing)
    }

    public func getStatus() -> Int {
        _status.load(ordering: .relaxed)
    }

    static func ==(lhs: TCNode, rhs: TCNode) -> Bool {
        lhs === rhs
    }


}


class WaitQNode: TCNode {

    var _nextPtr: NodePtr? = nil

}