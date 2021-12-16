import Foundation
import Atomics

public class Semaphore {
    private static let semCnt = ManagedAtomic<Int>(0)

    let tokens: SelectableChannel<Int>

    public init(_ n: Int, name: String = "sem",
                writeLock: Lock = NonFairLock(10), readLock: Lock = NonFairLock(10)) throws {
        let q = LinkedListQueue<Int>(max: n+1)
        let s = AnyStore(q)
        let semCnt = Semaphore.semCnt.loadThenWrappingIncrement(ordering: .relaxed)
        tokens = SelectableChannel(id: "\(name):\(semCnt)", store: s, writeLock: writeLock, readLock: readLock)
        for _ in 1...n {
            try tokens.write(1)
        }
    }

    public func take() -> Void {
        do {
            try tokens.read()
        } catch {
            // error
        }
    }

    public func take(_ n: Int) -> Void {
        var into: [Int?] = []
        do {
            repeat {
                try tokens.read(into: &into, upTo: n - into.count)
            } while into.count < n
        } catch {
            // error
        }
    }

    public func release() throws -> Void {
        try tokens.write(1)
    }

    public func release(_ n: Int) throws -> Void {
        var i = 0
        while i < n {
            try tokens.write(1)
            i += 1
        }
    }

}
