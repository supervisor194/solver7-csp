import Foundation
import Atomics

/**
 This CountdownLatch2 requires that one call await() in order to get a valid signal.  One can the check the get()
 for the number of tokens at the moment after an await()
 */
public class CountdownLatch2 {

    private static let latchCnt = ManagedAtomic<Int>(0)

    private let c: SelectableChannel<Int>
    private let t: Timeout<String>

    private var tokens: Int

    private var selector: Selector

    private var timedout = false

    public init(_ n: Int, writeLock: Lock = NonFairLock(10), readLock: Lock = NonFairLock(10)) throws {
        tokens = n

        let q = LinkedListQueue<Int>(max: 10)
        let s = AnyStore<Int>(q)
        let latchCnt = CountdownLatch2.latchCnt.loadThenWrappingIncrement(ordering: .relaxed)
        c = SelectableChannel<Int>(id: "latch:\(latchCnt)", store: s, writeLock: writeLock, readLock: readLock)
        t = Timeout<String>(id: "latchTimeout:\(latchCnt)")
        var selectables = [Selectable]()
        selectables.append(c)
        selectables.append(t)
        selector = try FairSelector(selectables)
        c.setHandler(handleC)
        t.setHandler(handleT)
    }


    private func handleC() -> Void {
        do {
            let n = try c.read()!
            tokens = max(0, tokens - n)
        } catch {
            // error
        }
    }

    private func handleT() -> Void {
        t.read()
        timedout = true
    }

    public func await(_ timeoutTime: timespec) {
        if tokens == 0 {
            return
        }

        t.setTimeout(timeoutTime)

        while true {
            let s = selector.select()
            s.handle()
            if timedout {
                return
            }
            if tokens == 0 {
                return
            }
        }
    }

    public func countDown() throws -> Void {
        try c.write(1)
    }

    public func countDown(_ n: Int) throws -> Void {
        try c.write(n)
    }

    public func get() -> Int {
        tokens
    }


}
