import XCTest
@testable import Solver7CSP

import Foundation

class SemaphoreTests : XCTestCase {

    public func testBasic() throws {
        let N = 10
        var cnt = 0
        let s = try Semaphore(1, writeLock: NonFairLock(11), readLock: NonFairLock(11))
        let latch = try CountdownLatch2(N, writeLock: NonFairLock(1), readLock: NonFairLock(1))
        s.take()
        for i in 1...10 {
            let tc = ThreadContext(name: "t\(i)") {
                for _ in 1...100 {
                    s.take()
                    cnt+=1
                    s.release()
                }
                latch.countDown()
            }
            XCTAssertEqual(0, tc.start())
        }
        s.release()
        latch.await(TimeoutState.computeTimeoutTimespec(sec: 5))
        XCTAssertEqual(100*10, cnt)
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
            s.release(100)
            l1.countDown()
        }
        XCTAssertEqual(0, tc.start())
        let tc2 = ThreadContext(name: "t2") {
            l1.await(TimeoutState.computeTimeoutTimespec(sec: 5))
            s.take(100)
            cnt+=1
            s.release(20)
            for _ in 1...50 {
                s.release(1)
            }
            for _ in 1...30 {
                s.release()
            }
            s.take(100)
            latch.countDown()
        }
        XCTAssertEqual(0, tc2.start())
        l0.countDown()
        s.release(90)
        latch.await(TimeoutState.computeTimeoutTimespec(sec: 5))
        XCTAssertEqual(2, cnt)
    }
}
