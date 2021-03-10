import XCTest
@testable import Solver7CSP

import Foundation

class TimeoutTests: XCTestCase {

    public func testComputeTimeoutTimespec() throws {
        var now = timeval()
        gettimeofday(&now, nil)
        let ts = TimeoutState.computeTimeoutTimespec(sec: 5, nanos: 500000000, now: now)

        var seconds = now.tv_sec + 5
        var nsec = (Int)(now.tv_usec) * 1000 + 500000000

        if nsec > 1000000000 {
            seconds += 1
            nsec -= 1000000000
        }
        XCTAssertEqual(seconds, ts.tv_sec)
        XCTAssertEqual(nsec, ts.tv_nsec)
    }

    public func testComputeTimeoutTimespecWithMillis() throws  {
        var now = timeval()
        gettimeofday(&now, nil)
        let ts = TimeoutState.computeTimeoutTimespec(millis: 37500, now: now)

        var seconds = now.tv_sec + 37
        var nsec = (Int) ( now.tv_usec) * 1000 + 500000000

        if nsec > 1000000000 {
            seconds += 1
            nsec -= 1000000000
        }
        XCTAssertEqual(seconds, ts.tv_sec)
        XCTAssertEqual(nsec, ts.tv_nsec)
    }

    public func testExpirations() throws {
        var now = timeval()
        gettimeofday(&now, nil)
        let timeoutTimespec = TimeoutState.computeTimeoutTimespec(sec: 2, nanos: 300)
        XCTAssertFalse( TimeoutState.earlier(time: timeoutTimespec, earlierThan: now))
        now.tv_sec += 1
        XCTAssertFalse( TimeoutState.earlier(time: timeoutTimespec, earlierThan: now))
        now.tv_sec += 1
        XCTAssertFalse( TimeoutState.earlier(time: timeoutTimespec, earlierThan: now))
        now.tv_usec += 1001
        XCTAssertTrue( TimeoutState.earlier(time: timeoutTimespec, earlierThan: now))
    }

    static var allTests = [
        ("testComputeTimeoutTimespec", testComputeTimeoutTimespec),
        ("testComputeTimeoutTimespecWithMillis", testComputeTimeoutTimespecWithMillis),
        ("testExpirations", testExpirations),
    ]

}
