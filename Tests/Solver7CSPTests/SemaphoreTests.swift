import XCTest
@testable import Solver7CSP

import Foundation

class SemaphoreTests: XCTestCase {

    public func testBasic() throws {
        let N = 10
        var cnt = 0
        let s = try Semaphore(1, writeLock: NonFairLock(11), readLock: NonFairLock(11))
        let latch = try CountdownLatch2(N, writeLock: NonFairLock(1), readLock: NonFairLock(1))
        s.take()
        for i in 1...10 {
            let tc = ThreadContext(name: "t\(i)") {
                do {
                    for _ in 1...100 {
                        s.take()
                        cnt += 1
                        try s.release()
                    }
                    try latch.countDown()
                } catch {
                    XCTFail("problems with release or countdown")
                }
            }
            XCTAssertEqual(0, tc.start())
        }
        try s.release()
        latch.await(TimeoutState.computeTimeoutTimespec(sec: 5))
        XCTAssertEqual(100 * 10, cnt)
    }

    public func testNPer() throws {
        var cnt = 0
        let l0 = try CountdownLatch2(1, writeLock: NonFairLock(1), readLock: NonFairLock(1))
        let l1 = try CountdownLatch2(1, writeLock: NonFairLock(1), readLock: NonFairLock(1))
        let latch = try CountdownLatch2(1, writeLock: NonFairLock(1), readLock: NonFairLock(1))
        let s = try Semaphore(100, writeLock: NonFairLock(2), readLock: NonFairLock(2))
        s.take(90)
        let tc = ThreadContext(name: "t") {
            l0.await(TimeoutState.computeTimeoutTimespec(sec: 5))
            s.take(50)
            for _ in 1...50 {
                s.take(1)
            }
            cnt += 1
            do {
                try s.release(100)
                try l1.countDown()
            } catch {
                XCTFail("problems with release or countdown")
            }
        }
        XCTAssertEqual(0, tc.start())
        let tc2 = ThreadContext(name: "t2") {
            l1.await(TimeoutState.computeTimeoutTimespec(sec: 5))
            s.take(100)
            cnt += 1
            do {
                try s.release(20)
                for _ in 1...50 {
                    try s.release(1)
                }
                for _ in 1...30 {
                    try s.release()
                }
                s.take(100)
                try latch.countDown()
            } catch {
                XCTFail("problems with release or countdown")
            }
        }
        XCTAssertEqual(0, tc2.start())
        try l0.countDown()
        try s.release(90)
        latch.await(TimeoutState.computeTimeoutTimespec(sec: 5))
        XCTAssertEqual(2, cnt)
    }

    static var allTests = [
        ("testBasic", testBasic),
        ("testNPer", testNPer),
    ]
}
