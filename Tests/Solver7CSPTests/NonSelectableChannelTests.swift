import XCTest
@testable import Solver7CSP

import Foundation

class NonSelectableChannelTests : XCTestCase {

    func testSingleValueStore() {

        let svs = SingleValueStore<Int>()
        let s = AnyStore<Int>(svs)
        let c = NonSelectableChannel<Int>(store: s, lockType: LockType.NON_FAIR_LOCK)

        var t1 = timeval()
        var t2 = timeval()

        let w1 = { ()->Void in
            gettimeofday(&t1, nil)
            c.write(77)
            gettimeofday(&t2, nil)
        }
        let writer = ThreadContext(name: "w1", execute: w1)

        var readTime = timeval()
        var i = 0
        var done = false
        let r1 = { ()->Void in
            sleep(3)
            gettimeofday(&readTime, nil)
            let val = c.read()!
            i = val
            done = true
        }
        let reader = ThreadContext(name: "r1", execute: r1)

        XCTAssertTrue(s.isEmpty())
        XCTAssertFalse(s.isFull())
        reader.start()
        writer.start()

        sleep(1)
        XCTAssertEqual( StoreState.FULL, s.state)
        XCTAssertTrue( s.isFull())
        XCTAssertFalse(s.isEmpty())

        while !done {
            sleep(1)
        }
        XCTAssertEqual(77, i)

        // want to know that time t2 ~= readTime and about 3 seconds later than t1
        XCTAssertTrue(  abs(TimeoutState.differenceInUSec(t2, readTime)) < 1000)
        XCTAssertTrue(  TimeoutState.differenceInUSec(readTime, t1) > 2900000)
        XCTAssertEqual( 0, s.count)
        XCTAssertEqual( StoreState.EMPTY, s.state)
    }



    func testSingleValueStoreViaLLQ() {
        let q = LinkedListQueue<String>(max: 1)
        let s = AnyStore<String>(q)
        let c = NonSelectableChannel<String>(store: s, lockType: LockType.NON_FAIR_LOCK)

        var t1 = timeval()
        var t2 = timeval()

        let w1 = { ()->Void in
            gettimeofday(&t1, nil)
            c.write("hello there")
            gettimeofday(&t2, nil)
        }
        let writer = ThreadContext(name: "w1", execute: w1)

        var readTime = timeval()
        class wrap {
            var s: String? = nil
        }
        let msg = wrap()
        var done = false
        let r1 = { ()->Void in
            sleep(3)
            gettimeofday(&readTime, nil)
            let s = c.read()!
            msg.s = s
            done = true
        }
        let reader = ThreadContext(name: "r1", execute: r1)

        reader.start()
        writer.start()

        while !done {
            sleep(1)
        }
        XCTAssertEqual("hello there", msg.s )

        // want to know that time t2 ~= readTime and about 3 seconds later than t1
        XCTAssertTrue(  abs(TimeoutState.differenceInUSec(t2, readTime)) < 1000)
        XCTAssertTrue(  TimeoutState.differenceInUSec(readTime, t1) > 2900000)
    }


    func testFoo() {
        let q = LinkedListQueue<MyInt64>(max: 100)
        let s = AnyStore<MyInt64>(q)
        let c = NonSelectableChannel<MyInt64>(store: s, lockType: LockType.NON_FAIR_LOCK)

        print("count is: \(q.count)")
        c.write(MyInt64(100))

        print("count is: \(q.count)")
        let val = c.read()
        print("value is: \(val?.val)")

        c.write(nil)
        print("count is: \(q.count)")

        let val2 = c.read()

        print("we have a : \(val2)")
        print("count is: \(q.count)")
    }

    func testFull() {

        let q = LinkedListQueue<String>(max:10)
        let s = AnyStore<String>(q)
        let c = NonSelectableChannel<String>(store: s, lockType: LockType.NON_FAIR_LOCK)


        func dm() -> Void {
            print("in reader dm")
        }

        let r = { () -> Void in
            var cnt = 0
            repeat {
                let x = c.read()
                print("got: \(x) at: \(cnt)")
                cnt += 1
                // sleep(1)
            } while cnt<100
            print("done with reader...")
        }
        let tc = ThreadContext(name: "reader", destroyMe: dm, execute: r)
        tc.start()

        for i in 1...100 {
            print("writing howdy doody \(i)")
            c.write("howdy doody \(i)")
        }

    }

    static var allTests = [
        ("testFoo", testFoo),
        ("testFull", testFull),
        ("testSingleValueStoreViaLLQ", testSingleValueStoreViaLLQ),
    ]
}
