import Foundation

public class NonFairLock: ReentrantLock {

    override public func lock() -> Void {
        let tc = ThreadContext.currentContext()
        if state.compareExchange(expected: NonFairLock.UNLOCKED, desired: NonFairLock.LOCKED, ordering: .relaxed).exchanged {
            lockingTc = tc
            return
        }
        if lockingTc !== tc {
            schedule(tc)
            lockingTc = tc
        }
    }

}
