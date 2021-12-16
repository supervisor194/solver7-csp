import Foundation
import Atomics


open class LockBase {

    internal var lockingTc: ThreadContext? = nil
    internal let state = ManagedAtomic<Int>(0)
    var depth = 0

    // Build a non locking queue with tail and head.
    // The tail is managed via a pointer to a Node to enable atomic modifications
    private let waitQTailPtr: UnsafeAtomic<NodePtr>
    var waitQHeadPtr: UnsafeAtomic<NodePtr>

    // private let waiterQ: LinkedListQueue<TCNode>
    // private let waiterPool: LinkedListQueue<TCNode>

    // todo: determine if we should keep maxThreads and pooling with circular buffer ???
    let maxThreads: Int

    public init(_ maxThreads: Int) {
        self.maxThreads = maxThreads
        let firstNode = WaitQNode(status: LockState.UNLOCKED)
        let firstNodePtr = UnsafeMutablePointer<WaitQNode>.allocate(capacity: 1)
        firstNodePtr.initialize(to: firstNode)
        var node = firstNode
        for _ in 1...maxThreads {
            let newNode = WaitQNode(status: LockState.UNLOCKED)
            let newNodePtr = UnsafeMutablePointer<WaitQNode>.allocate(capacity: 1)
            newNodePtr.initialize(to: newNode)
            node._nextPtr = newNodePtr
            node = newNode
        }
        node._nextPtr = firstNodePtr

        waitQTailPtr = UnsafeAtomic<NodePtr>.create(firstNodePtr)
        waitQHeadPtr = UnsafeAtomic<NodePtr>.create(firstNodePtr)

        /*
        waiterQ = LinkedListQueue<TCNode>(max: maxThreads)
        waiterPool = LinkedListQueue<TCNode>(max: maxThreads)
        for _ in 1...maxThreads {
            waiterPool.put(TCNode(status: WaiterState.WAITER_INITIAL))
        }
         */
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
            if !tail.compareAndSetStatus(expectedStatus: WaiterState.WAITER_INITIAL, desiredStatus: WaiterState.WAITER_NEED_SIGNAL) {
                tc.down()
            }
        }
        // tail is/was  the waitQHead
        while !state.compareExchange(expected: LockState.UNLOCKED, desired: LockState.LOCKED, ordering: .relaxed).exchanged {
            if !tail.compareAndSetStatus(expectedStatus: WaiterState.WAITER_INITIAL, desiredStatus: WaiterState.WAITER_NEED_SIGNAL) {
                tc.down()
            }
        }
        tail.setStatus(status: WaiterState.WAITER_INITIAL)
        tail._tc = nil
        waitQHeadPtr.store(tail._nextPtr!, ordering: .relaxed)
    }

    public func unlock() -> Void {
        if ThreadContext.currentContext() !== lockingTc {
            fatalError("can't unlock(), we don't own the lock!!!")
        }
        depth -= 1
        if depth == 0 {
            lockingTc = nil
            state.store(LockState.UNLOCKED, ordering: .relaxed)
            let waitQHead = waitQHeadPtr.load(ordering: .relaxed).pointee
            if let tc = waitQHead._tc {
                if waitQHead.compareAndSetStatus(expectedStatus: WaiterState.WAITER_NEED_SIGNAL,
                        desiredStatus: WaiterState.WAITER_INITIAL) {
                    tc.up()
                }
            }
        }
    }

    /*
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

    public func doWait(_ timeoutAt: inout timespec) -> Void {
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
    */

    public func reUp() -> Void {
        if let ltc = lockingTc {
            ltc.up()
        }
    }


}






/*


T1     lock     lock     lock.await     unlock   unlock      T1.lock.depth
                            waiter.depth = 2

T2          lock   lock.notify      unlock                   T2.lock.depth


T3   lock  lock.await  lock        lock.await                  unlock unlock
               waiter.depth = 1         waiter.depth = 2



   Condition c = lock.createCondition()



       c.await()  {

 */