import Foundation
import Atomics
import XCTest

@testable import Solver7CSP

class CountdownLatch2Tests: XCTestCase {

    public func testAwaitBeforeCountdown2() throws {
        let latch = try CountdownLatch2(1)
        let x = ManagedAtomic<Int>(1)
        let w = ThreadContext(name: "writer") {
            x.store(0, ordering: .relaxed)
            sleep(1)
            do {
                try latch.countDown()
            } catch {
                XCTFail("problems with countdown")
            }
        }
        w.start()
        while x.load(ordering: .relaxed) == 1 {
            usleep(1000)
        }
        var timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 5000)
        latch.await(timeoutAt)
        XCTAssertEqual(0, latch.get())
    }

    public func testCountDownBeforeAwait() throws {
        let latch = try CountdownLatch2(1)
        let x = ManagedAtomic<Int>(1)

        let w = ThreadContext(name: "writer") {
            do {
                try latch.countDown()
            } catch {
                XCTFail("problems with countdown")
            }
            x.store(0, ordering: .relaxed)
        }
        w.start()

        while x.load(ordering: .relaxed) == 1 {
            usleep(1000)
        }
        sleep(1)
        var timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 5000)
        latch.await(timeoutAt)
        latch.await(timeoutAt)
        latch.await(timeoutAt)
        latch.await(timeoutAt)
        XCTAssertEqual(0, latch.get())
    }

    static var allTests = [
        ("testAwaitBeforeCountdown2", testAwaitBeforeCountdown2),
        ("testCountDownBeforeAwait", testCountDownBeforeAwait),
    ]

}
