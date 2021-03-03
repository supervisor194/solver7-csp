import Foundation
import Atomics

public class CountdownLatch {

    private let n: ManagedAtomic<Int>

    private let l: Lock

    public init(_ n: Int, _ maxThreads: Int = 10) {
        self.n = ManagedAtomic<Int>(n)
        l = NonFairLock(maxThreads)
    }

    public func await(_ timeoutTime: inout timespec) {
        l.lock()
        defer {
            l.unlock()
        }
        while n.load(ordering: .relaxed) != 0 {
            l.doWait(&timeoutTime)
        }
    }

    public func countDown() -> Void {
        if n.wrappingDecrementThenLoad(ordering: .relaxed) <= 0 {
            l.lock()
            defer {
                l.unlock()
            }
            l.doNotify()
        }
    }

    public func countDown(_ by: Int) ->Void {
        if n.wrappingDecrementThenLoad(by: by, ordering: .relaxed) <= 0 {
            l.lock()
            defer {
                l.unlock()
            }
            l.doNotify()
        }
    }

    public func get() -> Int {
        let c = n.load(ordering: .relaxed)
        if c < 0 {
            n.store(0, ordering: .relaxed)
            return 0
        }
        return c
    }

}
