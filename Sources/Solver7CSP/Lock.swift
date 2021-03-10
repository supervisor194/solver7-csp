import Foundation
import Atomics

struct WaiterState {
    static let WAITER_INITIAL: Int = 0
    static let WAITER_NEED_SIGNAL: Int = 1
    static let WAITER_SIGNALED: Int = 2
}

struct LockState {
    static let UNLOCKED: Int = 0
    static let LOCKED: Int = 1
}

public protocol Lock {

    func lock() -> Void

    func unlock() -> Void

    func createCondition() -> Condition
    /*
    func doWait() -> Void

    func doWait(_ timeoutAt: inout timespec) -> Void

    func doNotify() -> Void
     */

    func reUp() -> Void
}


public class Condition {
    let lock: Lock

    private let waiterQ: LinkedListQueue<TCNode>
    // private let waiterPool: LinkedListQueue<TCNode>

    init(_ lock: Lock) {
        self.lock = lock
        waiterQ = LinkedListQueue<TCNode>(max: 10000) // todo: fix hardcoding / remove pooling ??? don't think it helps
    }

    public func doWait() -> Void {
        // a - let waiter = waiterPool.get()!
        let waiter = TCNode(status: WaiterState.WAITER_INITIAL)
        waiter._tc = ThreadContext.currentContext()
        // a - waiter.setStatus(status: WaiterState.WAITER_INITIAL)
        waiterQ.put(waiter)
        lock.unlock()
        if waiter.compareAndSetStatus(expectedStatus: WaiterState.WAITER_INITIAL, desiredStatus: WaiterState.WAITER_NEED_SIGNAL) {
            while waiter.getStatus() == WaiterState.WAITER_NEED_SIGNAL {
                waiter._tc!.down()
            }
        }
        lock.lock()
        waiter._tc = nil
        if waiter.getStatus() != WaiterState.WAITER_SIGNALED {
            print("not signalled...")
            if waiterQ.remove(waiter) {
                print("removed waiter leaving doWait()")
            }
        }
        // a - waiterPool.put(waiter)
    }

    public func doWait(_ timeoutAt: inout timespec) -> Void {
        // a - let waiter = waiterPool.get()!
        let waiter = TCNode(status: WaiterState.WAITER_INITIAL)
        waiter._tc = ThreadContext.currentContext()
        // a - waiter.setStatus(status: WaiterState.WAITER_INITIAL)
        waiterQ.put(waiter)
        // releasing the lock
        lock.unlock()
        if waiter.compareAndSetStatus(expectedStatus: WaiterState.WAITER_INITIAL, desiredStatus: WaiterState.WAITER_NEED_SIGNAL) {
            while waiter.exchangeStatus(status: WaiterState.WAITER_NEED_SIGNAL) == WaiterState.WAITER_NEED_SIGNAL
                          && !TimeoutState.expired(timeoutAt) {
                waiter._tc?.down(&timeoutAt)
            }
        }
        lock.lock()
        // we now have the lock again
        waiter._tc = nil
        if waiter.getStatus() != WaiterState.WAITER_SIGNALED {
            waiterQ.remove(waiter)
        }
        // a - waiterPool.put(waiter)
    }

    public func doNotify() {
        if !waiterQ.isEmpty() {
            let head = waiterQ.get()!
            if head.exchangeStatus(status: WaiterState.WAITER_SIGNALED) == WaiterState.WAITER_NEED_SIGNAL {
                // print("w: \(Unmanaged.passUnretained(head).toOpaque()) up: \(head._tc!.name)")
                head._tc?.up()
            }
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

typealias NodePtr = UnsafeMutablePointer<WaitQNode>

class WaitQNode: TCNode {
    var _nextPtr: NodePtr? = nil
}
