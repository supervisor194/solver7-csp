import Foundation
import Atomics

public class Semaphore {
    private static let semCnt = ManagedAtomic<Int>(0)

    let tokens: SelectableChannel<Int>

    public init(_ n: Int, name: String = "sem", maxWriters: Int = 10, maxReaders: Int = 10) throws {
        let q = LinkedListQueue<Int>(max: n + 1)
        let s = AnyStore(q)
        let semCnt = Semaphore.semCnt.loadThenWrappingIncrement(ordering: .relaxed)
        tokens = SelectableChannel(id: "\(name):\(semCnt)", store: s,
                maxWriters: maxWriters, maxReaders: maxReaders, lockType: LockType.NON_FAIR_LOCK)
        for _ in 1...n {
            tokens.write(1)
        }
    }

    public func take() -> Void {
        tokens.read()
    }

    public func take(_ n: Int) -> Void {
        var into: [Int?] = []
        repeat {
            tokens.read(into: &into, upTo: n - into.count)
        } while into.count < n
    }

    public func release() -> Void {
        tokens.write(1)
    }

    public func release(_ n: Int) -> Void {
        var i = 0
        while i < n {
            tokens.write(1)
            i += 1
        }
    }

}
