import XCTest
@testable import Solver7CSP


import Foundation
import Darwin.C

class LockTests: XCTestCase {

    func testOneThread() throws {
        var cnt = 0
        let latch = try CountdownLatch(1)
        let lock = NonFairLock(maxThreads: 2)
        var xyz = 99
        let myRunnable = { () -> Void in
            sleep(1)
            print("thread locking foo2")
            lock.lock()
            lock.lock()
            lock.lock()
            xyz = -1
            print("thread sleeping another 2")
            sleep(1)
            print("thread notifying any waiters")
            lock.doNotify()
            print("thread unlocking foo2")
            cnt += 1
            lock.unlock()
            print("thread unlocked foo2")
            latch.countDown()
        }

        func dm() -> Void {
            print("in the destroy me for myRunnable")
        }

        let tc = ThreadContext( name: "howdy doody", destroyMe: dm, execute: myRunnable)
        tc.start()
        XCTAssertEqual(-1, tc.start())

        lock.lock()
        lock.doWait()
        lock.unlock()

        let tc2 = ThreadContext(name: "foo") {
            lock.lock();
            cnt+=1
            lock.unlock()
            latch.countDown()
        }
        tc2.start()


        latch.await(TimeoutState.computeTimeoutTimespec(sec: 5, nanos: 0))
        XCTAssertEqual(0, latch.get())
        XCTAssertEqual(-1, xyz)
        XCTAssertEqual(2, cnt)

    }

    func testAnother() {
        print("starting")
        defer {
            print("all done") }
        do {
            print("in 1 deep")
         do   {
                print("in 2 deep")
                defer {
                    print("defer from 2 deep")
                }
            }
            print("back in 1 deep")
        }
    }

    func testMultipleDoWaits() throws {

        let latch = try CountdownLatch(20)

        let lock = NonFairLock(maxThreads: 20)

        for i in 1...20 {
            let tc = ThreadContext.init(name: "test:\(i)") {
                lock.lock()
                lock.doWait()
                lock.unlock()
                print("done with \(ThreadContext.currentContext().name)")
                latch.countDown()
            }
            tc.start()
        }

        sleep(3)

        for _ in 1...20 {
            sleep(1)
            lock.lock()
            lock.doNotify()
            lock.unlock()

        }

        latch.await(TimeoutState.computeTimeoutTimespec(sec: 120))


    }

    func test100Threads() {

        var xyz = 99

        let lock = NonFairLock(maxThreads: 100)

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
                print("in the destroy me for myRunnable")
            }

            let tc = ThreadContext(name: String(i), destroyMe: dm, execute: r)
            tcs.append(tc)
        }

        for tc in tcs {
            tc.start()
        }
        lock.lock()
        while xyz != 0 {
            print("waiting...")
            lock.doWait()
        }
        lock.unlock()

        print("done")
        XCTAssertEqual(0, xyz)

    }

    static var allTests = [
        ("testOneThread", testOneThread),
    ]
}
