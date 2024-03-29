import XCTest
@testable import Solver7CSP

import Foundation

class LatchTests :XCTestCase  {

    public func testManyThreadsTo0() throws {
        let latch = try CountdownLatch2(1000)

        let r1 = { () -> Void in
            do {
                for _ in 1...100 {
                    try latch.countDown()
                }
            } catch {
                XCTFail("problems with countdown")
            }
        }

        let r2 = { () -> Void in
            do {
                for _ in 1...10 {
                    try latch.countDown(50)
                }
            } catch {
                XCTFail("problems with countdown")
            }
        }

        let r3 = { () -> Void in
            do {
                for _ in 1...100 {
                    try latch.countDown(4)
                }
            } catch {
                XCTFail("problems with countdown")
            }
        }

        let tc1 = ThreadContext(name: "r1", execute: r1)
        XCTAssertEqual(0, tc1.start())
        let tc2 = ThreadContext(name: "r2", execute: r2)
        XCTAssertEqual(0, tc2.start())
        let tc3 = ThreadContext(name: "r3", execute: r3)
        XCTAssertEqual(0, tc3.start())

        var t1 = timeval()
        gettimeofday(&t1, nil)
        latch.await(TimeoutState.computeTimeoutTimespec(sec: 5, nanos: 0))
        var t2 = timeval()
        gettimeofday(&t2, nil)

        XCTAssertTrue(TimeoutState.differenceInUSec(t1, t2) < 10000)
        XCTAssertEqual(0, latch.get())
    }

    public func testOneBigDecrementBeyond0() throws {
        let latch = try CountdownLatch2(100)

        let r1 = { () -> Void in
            sleep(1)
            do {
                try latch.countDown(500)
            } catch {
                XCTFail("problems with countdown")
            }
        }
        let tc = ThreadContext(name: "r1", execute: r1)
        XCTAssertEqual(0, tc.start())

        var t1 = timeval()
        gettimeofday(&t1, nil)
        latch.await(TimeoutState.computeTimeoutTimespec(sec: 5, nanos: 0))
        var t2 = timeval()
        gettimeofday(&t2, nil)

        XCTAssertTrue(TimeoutState.differenceInUSec(t1, t2) < 10000)
        XCTAssertEqual(0, latch.get())
    }


    public func testTimeout() throws {
        let latch = try CountdownLatch2(100)

        var t1 = timeval()
        gettimeofday(&t1, nil)
        latch.await(TimeoutState.computeTimeoutTimespec(sec: 2, nanos: 100000))
        var t2 = timeval()
        gettimeofday(&t2, nil)

        XCTAssertTrue( abs(TimeoutState.differenceInUSec(t1, t2)) > 2000000)
        XCTAssertEqual(100, latch.get())
    }


    public func testCountdownLatch() throws  {
        let latch = try CountdownLatch(100)
        let tc = ThreadContext(name: "writer") {
            for _ in 1...90 {
                latch.countDown()
            }
            latch.countDown(5)
            latch.countDown(5)
        }
        XCTAssertEqual(0, tc.start())
        var timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 3000)
        latch.await(&timeoutAt)
        XCTAssertEqual(0, latch.get())
    }

    public func testCountdownLatchExceed() throws {
        let latch = try CountdownLatch(100)
        let tc = ThreadContext(name: "writer") {
            for _ in 1...90 {
                latch.countDown()
            }
            latch.countDown(50)
        }
        XCTAssertEqual(0, tc.start())
        var timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 3000)
        latch.await(&timeoutAt)
        XCTAssertEqual(0, latch.get())
    }


    public func testCountdownLatchTimeout() throws  {
        let latch = try CountdownLatch(100)

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
        ("testTimeout", testTimeout),
        ("testCountdownLatch", testCountdownLatch),
        ("testCountdownLatchExceed", testCountdownLatchExceed),
        ("testCountdownLatchTimeout",testCountdownLatchTimeout),
    ]

}
