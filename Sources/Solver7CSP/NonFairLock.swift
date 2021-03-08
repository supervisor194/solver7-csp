import Foundation

public final class NonFairLock: ReentrantLock {

    override public final func lock() -> Void {
        let tc = ThreadContext.currentContext()
        if state.compareExchange(expected: NonFairLock.UNLOCKED, desired: NonFairLock.LOCKED, ordering: .relaxed).exchanged {
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

}
