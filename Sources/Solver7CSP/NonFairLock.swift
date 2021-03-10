import Foundation

public final class NonFairLock: LockBase, Lock {

    public func lock() -> Void {
        let tc = ThreadContext.currentContext()
        if state.compareExchange(expected: LockState.UNLOCKED, desired: LockState.LOCKED, ordering: .relaxed).exchanged {
            lockingTc = tc
            depth += 1
            return
        }
        if lockingTc !== tc {
            schedule(tc)
            lockingTc = tc
        }
        depth += 1
    }


    public func createCondition() -> Condition {
        Condition(self)
    }
}
