import Foundation
@testable import Solver7CSP
import XCTest

class ThreadContextTests : XCTestCase {


    public func testJoins() throws {
        let latch0 = CountdownLatch(1, 100)
        var tcs : [ThreadContext] = []
        for i in 1...100 {
            let tc = ThreadContext(name: "tc\(i)") {
                var timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 5000)
                latch0.await(&timeoutAt)
                XCTAssertEqual(0, latch0.get())
            }
            tc.start()
            tcs.append(tc)
        }
        latch0.countDown()

        for tc in tcs {
            var timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 5000)
            if tc.join(&timeoutAt) != 0 {
                XCTFail("should not get here")
            }
            XCTAssertEqual(ThreadContext.ENDED, tc.state)
        }
    }

    public func testJoinTimeout() throws  {
        let latch0 = CountdownLatch(1)
        let tc = ThreadContext(name: "timeout") {
            var timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 5000)
            latch0.await(&timeoutAt)
        }
        tc.start()
        var timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 500)
        XCTAssertEqual(1, tc.join(&timeoutAt))
        latch0.countDown()
        timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 500)
        XCTAssertEqual(0, tc.join(&timeoutAt))
    }
}
