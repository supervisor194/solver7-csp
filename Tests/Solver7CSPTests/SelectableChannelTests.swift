import XCTest
@testable import Solver7CSP

import Foundation

class SelectableChannelTests : XCTestCase {

    func testFoo() throws {
        let q = LinkedListQueue<String>(max: 100)
        let s = AnyStore<String>(q)
        let c = SelectableChannel<String>(id: "c1", store: s, writeLock: NonFairLock(2), readLock: NonFairLock(1))
        c.setHandler({ () -> Void in
            do {
            let str = try c.read()
                } catch {
                }
            // print("we have a string: \(str)")
        })

        let q2 = LinkedListQueue<Int>(max: 100)
        let s2 = AnyStore<Int>(q2)
        let c2 = SelectableChannel<Int>(id: "c2", store: s2, writeLock: NonFairLock(2), readLock: NonFairLock(1))
        c2.setHandler( { () -> Void in
            do {
            let i = try c2.read()
                } catch {
                }
            // print("we have an int: \(i)")
        })

        try c.write("howdy doody")
        try c2.write(77)

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
                do {
                    try c.write("string cnt \(i)")
                } catch {
                    XCTFail("problems with write")
                }
                sleep(1)
            }
        }
        let tc = ThreadContext(name: "howdy doody 1", execute: myRunnable)
        XCTAssertEqual(0, tc.start())

        let myRunnable2 = { () -> Void in
            for i in 1...10 {
                do {
                    try c2.write(i + 100)
                } catch {
                    XCTFail("problems with write")
                }
                sleep(1)
            }
        }
        let tc2 = ThreadContext(name: "howdy doody 2", execute: myRunnable2)
        XCTAssertEqual(0, tc2.start())

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

        // print ("all done")
    }

    public func testWithTimers() throws  {
        var numMsgs = 0

        let q = LinkedListQueue<String>(max: 10)
        let s = AnyStore<String>(q)
        let c = SelectableChannel<String>(id: "c1", store: s, writeLock: NonFairLock(1), readLock: NonFairLock(1))
        c.setHandler({ () -> Void in
            do {
                let str = try c.read()
                // print("we have a string: \(str))")
                numMsgs += 1
            } catch {
                XCTFail("problems with read")
            }
        })
        let writer = { () -> Void in
            var msgNum = 1
            do {
                for _ in 1...10 {
                    for _ in 1...5 {
                        try c.write("writer msg: \(msgNum)")
                        msgNum += 1
                    }
                    usleep(250000)
                }
            } catch {
                XCTFail("problems with write")
            }
            // print("done with writer")
        }
        let tc = ThreadContext(name: "writer1", execute: writer)
        XCTAssertEqual(0, tc.start())

        var numInts = 0

        let q2 = LinkedListQueue<Int>(max: 10)
        let s2 = AnyStore<Int>(q2)
        let c2 = SelectableChannel<Int>(id: "c2", store: s2, writeLock: NonFairLock(2), readLock: NonFairLock(1))
        c2.setHandler({ () -> Void in
            do {
                let i = try c2.read()
                // print("we have an int: \(i)")
                numInts += 1
            } catch {
                XCTFail("problems with read")
            }
        })
        let writer2 = { () -> Void in
            var intNum = 1
            do {
                for _ in 1...10 {
                    for _ in 1...5 {
                        try c2.write(intNum)
                        intNum += 1
                    }
                    usleep(200000)
                }
            } catch {
                XCTFail("problems with write")
            }
            // print("done with writer2")
        }
        let tc2 = ThreadContext( name: "writer2", execute: writer2)
        XCTAssertEqual(0, tc2.start())

        var done = false

        var timerNum = 0
        let t1 = Timeout<String>(id: "t1")
        t1.setHandler({ () -> Void in
            timerNum += 1
            let i = t1.read()
            // print("timer 1 has: \(i)")
            if timerNum == 20 {
                done=true
                return
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
        XCTAssertEqual(20, timerNum)

    }

    public func testClose() throws  {

        let ch1 = ChannelFactory.AsSelectable.SLLQ(id: "ch1", max: 10).create(t: Int.self)
        let ch2 = ChannelFactory.AsSelectable.SLLQ(id: "ch2", max: 10).create(t: String.self)
        let ch3 = ChannelFactory.AsSelectable.SLLQ(id: "ch3", max: 10).create(t: Double.self)

        var cnt = 0
        ch1.setHandler { ()->Void in
            do {
                if let x = try ch1.read() {
                    cnt += x
                } else {
                    ch1.disable()
                }
            } catch {
                XCTFail("problems with reader")
            }
        }
        var cnt2 = 0
        ch2.setHandler { ()->Void in
            do {
                if let x = try ch2.read() {
                    cnt2 += 1
                } else {
                    ch2.disable()
                }
            } catch {
                XCTFail("problems with reader")
            }
        }
        var sum = 0.0
        ch3.setHandler {
            do {
                if let x = try ch3.read() {
                    sum += x
                } else {
                    ch3.disable()
                }
            } catch {
                XCTFail("problems with reader")
            }
        }
        let latch = CountdownLatch(1)
        let timeout = Timeout<Any>(id:"myTimeout")
        timeout.setTimeout(TimeoutState.computeTimeoutTimespec(millis: 1000))
        timeout.setHandler {
            let val = timeout.read()
            latch.countDown()
        }
        var selectables = [Selectable]()
        selectables.append(ch1)
        selectables.append(ch2)
        selectables.append(ch3)
        selectables.append(timeout)

        let fs = try FairSelector(selectables)

        let p = ThreadContext(name: "processor") {
            while true {
                let selected = fs.select()
                selected.handle()
            }
        }
        p.start()

        try ch1.write(88)
        try ch2.write("howdy")
        try ch3.write(11.39)

        ch1.close()
        ch2.close()
        try ch3.write(3939.319)

        ch3.close()

        try ch1.write(99)
        try ch2.write("won't make it")
        try ch3.write(-10000.30)

        var timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 5000)
        latch.await(&timeoutAt)
        XCTAssertEqual(0, latch.get())

        XCTAssertEqual(88, cnt)
        XCTAssertEqual(1, cnt2)
        XCTAssertEqual(3950.709, sum)

    }

    static var allTests = [
        ("testWithTimers", testWithTimers),
        ("testFoo", testFoo),
        ("testClose", testClose),
    ]


}
