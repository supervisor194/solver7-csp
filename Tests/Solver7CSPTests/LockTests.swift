import XCTest
@testable import Solver7CSP


import Foundation
import Darwin.C

class LockTests: XCTestCase {

    func testNestedLocks() throws {
        var cnt = 0
        let l1 = try CountdownLatch(1)
        let l2 = try CountdownLatch2(1)
        let l3 = try CountdownLatch2(1)
        let l4 = try CountdownLatch(1)
        let lock = NonFairLock(5)
        var xyz = 99
        let myRunnable = { () -> Void in
            var timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 5000)
            l1.await(&timeoutAt)
            XCTAssertEqual(0, l1.get())
            lock.lock()
            lock.lock()
            lock.lock()
            xyz = -1
            lock.doNotify()
            cnt += 1
            lock.unlock()
            l2.countDown()
            lock.unlock()
            lock.unlock()
        }

        func dm() -> Void {
            // print("in the destroy me for myRunnable")
            l3.countDown()
        }

        let tc = ThreadContext( name: "howdy doody", destroyMe: dm, execute: myRunnable)
        XCTAssertEqual(0, tc.start())
        XCTAssertEqual(-1, tc.start())

        lock.lock()
        l1.countDown()
        lock.doWait()
        lock.unlock()

        let tc2 = ThreadContext(name: "foo") {
            lock.lock()
            l4.countDown()
            lock.lock()
            cnt+=1
            lock.unlock()
            // lock.unlock()  add to fail by letting tc3 acquire lock
            l2.countDown()
        }
        XCTAssertEqual(0, tc2.start())

        let tc3 = ThreadContext(name: "CannotLock") {
            var timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 2000)
            l4.await(&timeoutAt)
            XCTAssertEqual(0, l4.get())
            lock.lock()
            XCTFail("should not get here")
        }
        tc3.start()

        l2.await(TimeoutState.computeTimeoutTimespec(sec: 5, nanos: 0))
        XCTAssertEqual(0, l2.get())
        XCTAssertEqual(-1, xyz)
        XCTAssertEqual(2, cnt)

        l3.await(TimeoutState.computeTimeoutTimespec(millis: 3000))
        XCTAssertEqual(0, l3.get())

        sleep(1)
    }


    func testMultipleDoWaits() throws {

        let latch = try CountdownLatch2(20)

        let lock = NonFairLock(20)

        for i in 1...20 {
            let tc = ThreadContext.init(name: "test:\(i)") {
                lock.lock()
                lock.doWait()
                lock.unlock()
                // print("done with \(ThreadContext.currentContext().name)")
                latch.countDown()
            }
            XCTAssertEqual(0, tc.start())
        }

        sleep(1)

        for _ in 1...20 {
            usleep(100)
            lock.lock()
            lock.doNotify()
            lock.unlock()

        }

        latch.await(TimeoutState.computeTimeoutTimespec(sec: 10))
    }

    func test100Threads() throws {

        var xyz = 99

        let latch = try CountdownLatch2(99, writeLock: NonFairLock(100), readLock: NonFairLock(1))

        let lock = NonFairLock(100)

        var tcs = [ThreadContext]()

        for i in 1...99 {
            let r = { () -> Void in
                sleep(1)
                lock.lock()
                xyz -= 1
                lock.doNotify()
                lock.unlock()
            }

            func dm() -> Void {
                // print("in the destroy me for myRunnable")
                latch.countDown()
            }

            let tc = ThreadContext(name: String(i), destroyMe: dm, execute: r)
            tcs.append(tc)
        }

        for tc in tcs {
            XCTAssertEqual(0, tc.start())
        }
        lock.lock()
        while xyz != 0 {
            // print("waiting...")
            lock.doWait()
        }
        lock.unlock()

        latch.await(TimeoutState.computeTimeoutTimespec(millis: 10000))
        XCTAssertEqual(0, latch.get())
        XCTAssertEqual(0, xyz)
    }


    public func testConditions() throws  {
        var lock = NonFairLock(10)
        var condition : [Condition] = []
        for _ in 1...10 {
            condition.append(lock.createCondition())
        }
        let l1 = try CountdownLatch(9)
        for i in 0...8 {
            let tc = ThreadContext(name: "\(i)") {
                l1.countDown()
                lock.lock()
                defer {
                    lock.unlock()
                }
                condition[i].doWait()
                usleep(200)
                condition[i+1].doNotify()
                print("\(i) done")
            }
            tc.start()
        }

        var timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 5000)
        l1.await(&timeoutAt)
        XCTAssertEqual(0, l1.get())

        let l = try CountdownLatch(1)
        let tc = ThreadContext(name: "activator") {
            lock.lock()
            print("main doing notify 0")
            condition[0].doNotify()
            print("main did notify, sleeping 1 before unlock")
            sleep(1)
            lock.unlock()

            lock.lock()
            print("main waiting on condition 9")
            condition[9].doWait()
            print("main, condition 9 done")
            lock.unlock()
            l.countDown()
        }
        tc.start()

        timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 5000)
        l.await(&timeoutAt)
        XCTAssertEqual(0, l.get())
    }

    static var allTests = [
        ("testNestedLocks", testNestedLocks),
        ("testConditions", testConditions),
        ("testMultipleDoWaits", testMultipleDoWaits),
        ("test100Threads", test100Threads),
    ]
}
