import Foundation

public class FairLock: ReentrantLock {

    override public func lock() -> Void {
        let tc = ThreadContext.currentContext()
        if state.load(ordering: .relaxed) == ReentrantLock.UNLOCKED {
            if waitQHeadPtr.load(ordering: .relaxed).pointee == nil {
                if state.compareExchange(expected: ReentrantLock.UNLOCKED,
                        desired: ReentrantLock.LOCKED, ordering: .relaxed).exchanged {
                    lockingTc = tc
                    depth += 1
                    return
                }
            }
        }
        if lockingTc !== tc {
            schedule(tc)
            lockingTc = tc
        }
        depth += 1
    }
}
