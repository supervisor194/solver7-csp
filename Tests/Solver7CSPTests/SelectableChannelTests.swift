import XCTest
@testable import Solver7CSP

import Foundation

class SelectableChannelTests : XCTestCase {

    func testFoo() throws {
        let q = LinkedListQueue<String>(max: 100)
        let s = AnyStore<String>(q)
        let c = SelectableChannel<String>(id: "c1", store: s, lockType: LockType.NON_FAIR_LOCK)
        c.setHandler({ () -> Void in
            print("we have a string: \(c.read())")
        })

        let q2 = LinkedListQueue<Int>(max: 100)
        let s2 = AnyStore<Int>(q2)
        let c2 = SelectableChannel<Int>(id: "c2", store: s2, lockType: LockType.NON_FAIR_LOCK)
        c2.setHandler( { () -> Void in
            print("we have an int: \(c2.read())")
        })

        c.write("howdy doody")
        c2.write(77)

        var selectables = [Selectable]()
        selectables.append(c)
        selectables.append(c2)

        let selector = try FairSelector(selectables)

        var selected = selector.select()
        selected.handle()

        selected = selector.select()
        selected.handle()


        let myRunnable = { () -> Void in
            for i in 1...10 {
                c.write("string cnt \(i)")
                sleep(2)
            }
        }
        let tc = ThreadContext(name: "howdy doody 1", execute: myRunnable)
        tc.start()

        let myRunnable2 = { () -> Void in
            for i in 1...10 {
                c2.write(i+100)
                sleep(1)
            }
        }
        let tc2 = ThreadContext(name: "howdy doody 2", execute: myRunnable2)
        tc2.start()

        var cnt = 0
        repeat {
            selected = selector.select()
            selected.handle()
            cnt += 1
        } while cnt<20

        XCTAssertTrue(selector.removeSelectable("c2"))
        XCTAssertTrue(selector.removeSelectable("c1"))
        XCTAssertFalse(selector.removeSelectable("c1"))
        XCTAssertFalse(selector.removeSelectable("c2"))

        print ("all done")
    }

    public func testWithTimers() throws  {
        var numMsgs = 0

        let q = LinkedListQueue<String>(max: 100)
        let s = AnyStore<String>(q)
        let c = SelectableChannel<String>(id: "c1", store: s, lockType: LockType.NON_FAIR_LOCK)
        c.setHandler({ () -> Void in
            print("we have a string: \(c.read())")
            numMsgs += 1
        })
        let writer = { () -> Void in
            var msgNum = 1
            for _ in 1...10 {
                for _ in 1...5 {
                    c.write("writer msg: \(msgNum)")
                    msgNum += 1
                }
                usleep(250000)
            }
            print("done with writer")
        }
        let tc = ThreadContext(name: "writer1", execute: writer)
        tc.start()

        var numInts = 0

        let q2 = LinkedListQueue<Int>(max: 100)
        let s2 = AnyStore<Int>(q2)
        let c2 = SelectableChannel<Int>(id: "c2", store: s2, lockType: LockType.NON_FAIR_LOCK)
        c2.setHandler({ () -> Void in
            print("we have an int: \(c2.read())")
            numInts += 1
        })
        let writer2 = { () -> Void in
            var intNum = 1
            for _ in 1...10 {
                for _ in 1...5 {
                    c2.write(intNum)
                    intNum += 1
                }
                usleep(200000)
            }
            print("done with writer2")
        }
        let tc2 = ThreadContext( name: "writer2", execute: writer2)
        tc2.start()


        var done = false

        var timerNum = 0
        let t1 = Timeout<String>(id: "t1")
        t1.setHandler({ () -> Void in
            timerNum += 1
            print("timer 1 has: \(t1.read())")
            if timerNum == 20 {
                done=true
            }
            t1.setTimeout(TimeoutState.computeTimeoutTimespec(sec: 0, nanos: 100000000), "timer: \(timerNum)")
        })
        let at = TimeoutState.computeTimeoutTimespec(sec: 1, nanos: 0)
        t1.setTimeout(at, "timer: \(timerNum)")

        var selectables = [Selectable]()
        selectables.append(c)
        selectables.append(t1)
        selectables.append(c2)

        let fs = try  FairSelector(selectables)

        var cnt = 0
        while !done {
            let selected = fs.select()
            selected.handle()
            cnt += 1
        }

        XCTAssertEqual(100, numMsgs+numInts)

    }


}
