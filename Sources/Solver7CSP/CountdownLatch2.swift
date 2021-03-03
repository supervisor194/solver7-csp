import Foundation
import Atomics

public class CountdownLatchViaChannel {

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
        let latchCnt = CountdownLatchViaChannel.latchCnt.loadThenWrappingIncrement(ordering: .relaxed)
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
        let n = c.read()!
        tokens = max(0, tokens - n)
    }

    private func handleT() -> Void {
        t.read()
        timedout = true
    }

    public func await(_ timeoutTime: timespec) {
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

    public func countDown() -> Void {
        c.write(1)
    }

    public func countDown(_ n: Int) -> Void {
        c.write(n)
    }

    public func get() -> Int {
        tokens
    }


}
