import XCTest
@testable import Solver7CSP

import Foundation

class LatchTests :XCTestCase  {

    public func testManyThreadsTo0() throws {
        let latch = try CountdownLatch(1000)

        let r1 = { () -> Void in
            for _ in 1...100 {
                latch.countDown()
            }
        }

        let r2 = { () -> Void in
            for _ in 1...10 {
                latch.countDown(50)
            }
        }

        let r3 = { () -> Void in
            for _ in 1...100 {
                latch.countDown(4)
            }
        }

        let tc1 = ThreadContext(name: "r1", execute: r1)
        tc1.start()
        let tc2 = ThreadContext(name: "r2", execute: r2)
        tc2.start()
        let tc3 = ThreadContext(name: "r3", execute: r3)
        tc3.start()

        var t1 = timeval()
        gettimeofday(&t1, nil)
        latch.await(TimeoutState.computeTimeoutTimespec(sec: 5, nanos: 0))
        var t2 = timeval()
        gettimeofday(&t2, nil)

        XCTAssertTrue(TimeoutState.differenceInUSec(t1, t2) < 10000)
        XCTAssertEqual(0, latch.get())
    }

    public func testOneBigDecrementBeyond0() throws {
        let latch = try CountdownLatch(100)

        let r1 = { () -> Void in
            sleep(1)
            latch.countDown(500)
        }
        let tc = ThreadContext(name: "r1", execute: r1)
        tc.start()

        var t1 = timeval()
        gettimeofday(&t1, nil)
        latch.await(TimeoutState.computeTimeoutTimespec(sec: 5, nanos: 0))
        var t2 = timeval()
        gettimeofday(&t2, nil)

        XCTAssertTrue(TimeoutState.differenceInUSec(t1, t2) < 10000)
        XCTAssertEqual(0, latch.get())
    }


    public func testTimeout() throws {
        let latch = try CountdownLatch(100)

        var t1 = timeval()
        gettimeofday(&t1, nil)
        latch.await(TimeoutState.computeTimeoutTimespec(sec: 2, nanos: 100000))
        var t2 = timeval()
        gettimeofday(&t2, nil)

        XCTAssertTrue( abs(TimeoutState.differenceInUSec(t1, t2)) > 2000000)
        XCTAssertEqual(100, latch.get())
    }


    public func testCountdownLatch2() throws  {
        let latch = try CountdownLatch2(100)
        let tc = ThreadContext(name: "writer") {
            for _ in 1...90 {
                latch.countDown()
            }
            latch.countDown(5)
            latch.countDown(5)
        }
        tc.start()
        var timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 3000)
        latch.await(&timeoutAt)
        XCTAssertEqual(0, latch.get())
    }

    public func testCountdownLatch2Exceed() throws {
        let latch = try CountdownLatch2(100)
        let tc = ThreadContext(name: "writer") {
            for _ in 1...90 {
                latch.countDown()
            }
            latch.countDown(50)
        }
        tc.start()
        var timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 3000)
        latch.await(&timeoutAt)
        XCTAssertEqual(0, latch.get())
    }


    public func testCountdownLatch2Timeout() throws  {
        let latch = try CountdownLatch2(100)

        var t1 = timeval()
        gettimeofday(&t1, nil)
        var timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 2100)
        latch.await(&timeoutAt)
        var t2 = timeval()
        gettimeofday(&t2, nil)

        XCTAssertTrue( abs(TimeoutState.differenceInUSec(t1,t2)) > 2000000)
        XCTAssertEqual(100, latch.get())

    }

    static var allTests = [
        ("testManyThreadsTo0", testManyThreadsTo0),
        ("testOneBigDecrementBeyond0", testOneBigDecrementBeyond0),
    ]

}
