import Foundation
import XCTest
import Atomics

@testable import Solver7CSP


class CountdownLatchTests : XCTestCase {


    public func testAwaitBeforeCountdown() throws  {
        let latch = CountdownLatch(1)
        let x = ManagedAtomic<Int>(1)
        let w = ThreadContext(name: "writer") {
            x.store(0, ordering: .relaxed)
            sleep(1)
            latch.countDown()
        }
        w.start()
        while x.load(ordering: .relaxed) == 1 {
            usleep(1000)
        }
        var timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 5000)
        latch.await(&timeoutAt)
        XCTAssertEqual(0, latch.get())
    }

    public func testCountDownBeforeAwait() throws {
        let latch = CountdownLatch(1)
        let x = ManagedAtomic<Int>(1)

        let w = ThreadContext(name: "writer") {
            latch.countDown()
            x.store(0, ordering: .relaxed)
        }
        w.start()

        while x.load(ordering: .relaxed) == 1 {
            usleep(1000)
        }
        XCTAssertEqual(0, latch.get())
        var timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 5000)
        latch.await(&timeoutAt)
        latch.await(&timeoutAt)
        latch.await(&timeoutAt)
        latch.await(&timeoutAt)
        XCTAssertEqual(0, latch.get())
    }



}
