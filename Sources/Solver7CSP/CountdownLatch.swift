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
        l.doWait(&timeoutTime)
    }

    public func countDown() -> Void {
        n.wrappingDecrement(by: 1, ordering: .relaxed)
    }

    public func countDown(_ by: Int) ->Void {
        n.wrappingDecrement(by: by, ordering: .relaxed)
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
