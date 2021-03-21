import XCTest
@testable import Solver7CSP
import Atomics
import Foundation

class NonSelectableChannelTests: XCTestCase {

    func testSingleValueStore() {

        let svs = SingleValueStore<Int>()
        let s = AnyStore<Int>(svs)
        let c = NonSelectableChannel<Int>(store: s)

        var t1 = timeval()
        var t2 = timeval()

        let w1 = { () -> Void in
            gettimeofday(&t1, nil)
            c.write(77)
            gettimeofday(&t2, nil)
        }
        let writer = ThreadContext(name: "w1", execute: w1)

        var readTime = timeval()
        var i = 0
        var done = false
        let r1 = { () -> Void in
            sleep(3)
            gettimeofday(&readTime, nil)
            let val = c.read()!
            i = val
            done = true
        }
        let reader = ThreadContext(name: "r1", execute: r1)

        XCTAssertTrue(s.isEmpty())
        XCTAssertFalse(s.isFull())
        XCTAssertEqual(0, reader.start())
        XCTAssertEqual(0, writer.start())

        sleep(1)
        XCTAssertEqual(StoreState.FULL, s.state)
        XCTAssertTrue(s.isFull())
        XCTAssertFalse(s.isEmpty())

        while !done {
            sleep(1)
        }
        XCTAssertEqual(77, i)

        // want to know that time t2 ~= readTime and about 3 seconds later than t1
        XCTAssertTrue(abs(TimeoutState.differenceInUSec(t2, readTime)) < 1000)
        XCTAssertTrue(TimeoutState.differenceInUSec(readTime, t1) > 2900000)
        XCTAssertEqual(0, s.count)
        XCTAssertEqual(StoreState.EMPTY, s.state)
    }


    func testSingleValueStoreViaLLQ() {
        let q = LinkedListQueue<String>(max: 1)
        let s = AnyStore<String>(q)
        let c = NonSelectableChannel<String>(store: s)

        var t1 = timeval()
        var t2 = timeval()

        let w1 = { () -> Void in
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
        let r1 = { () -> Void in
            sleep(3)
            gettimeofday(&readTime, nil)
            let s = c.read()!
            msg.s = s
            done = true
        }
        let reader = ThreadContext(name: "r1", execute: r1)

        XCTAssertEqual(0, reader.start())
        XCTAssertEqual(0, writer.start())

        while !done {
            sleep(1)
        }
        XCTAssertEqual("hello there", msg.s)

        // want to know that time t2 ~= readTime and about 3 seconds later than t1
        XCTAssertTrue(abs(TimeoutState.differenceInUSec(t2, readTime)) < 1000)
        XCTAssertTrue(TimeoutState.differenceInUSec(readTime, t1) > 2900000)
    }


    func testFoo() {
        let q = LinkedListQueue<MyInt64>(max: 100)
        let s = AnyStore<MyInt64>(q)
        let c = NonSelectableChannel<MyInt64>(store: s)

        XCTAssertEqual(0, q.count)
        c.write(MyInt64(100))

        XCTAssertEqual(1, q.count)
        let val = c.read()
        XCTAssertEqual(100, val?.val)

        c.write(nil)
        XCTAssertEqual(1, q.count)

        let val2 = c.read()
        XCTAssertEqual(nil, val2?.val)
        XCTAssertEqual(nil, val2)
        XCTAssertEqual(0, q.count)
    }

    func testFull() throws {

        let c = NonSelectableChannel(store: AnyStore(LinkedListQueue<String>(max: 10)))

        let l1 = try CountdownLatch2(1)

        func dm() -> Void {
            l1.countDown()
        }

        let l2 = try CountdownLatch2(100)
        let r = { () -> Void in
            var cnt = 0
            repeat {
                let x = c.read()
                cnt += 1
                l2.countDown()
            } while cnt < 100
        }
        let reader = ThreadContext(name: "reader", destroyMe: dm, execute: r)
        XCTAssertEqual(0, reader.start())

        let writer = ThreadContext(name: "writer") {
            for i in 1...100 {
                c.write("howdy doody \(i)")
            }
        }
        XCTAssertEqual(0, writer.start())

        l2.await(TimeoutState.computeTimeoutTimespec(millis: 3000))
        XCTAssertEqual(0, l2.get())

        l1.await(TimeoutState.computeTimeoutTimespec(millis: 3000))
        XCTAssertEqual(0, l1.get())
    }

    public func testApproachToClose() throws {
        let latch = CountdownLatch(1)
        let c = ChannelFactory.AsAny.LLQ(max: 10).create(t: Int.self)
        var sum = 0
        let tc = ThreadContext(name: "foo") {
            while true {
                if let x = c.read() {
                    sum += x
                } else {
                    latch.countDown()
                    return
                }
            }
        }
        tc.start()

        for i in 1...10 {
            c.write(i)
        }
        c.write(nil)

        var timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 5000)
        latch.await(&timeoutAt)
        XCTAssertEqual(0, latch.get())
        XCTAssertEqual((1 + 10) * 10 / 2, sum)
    }

    public func testJoins() throws {
        let c = ChannelFactory.AsAny.LLQ(max: 100, writeLock: NonFairLock(1),
                readLock: NonFairLock(1000)).create(t: Int.self)
        var readers: [ThreadContext] = []
        let writer = ThreadContext(name: "writer") {
            var r = SystemRandomNumberGenerator()
            while true {
                c.write(Int(r.next() % 100000))
                usleep(100)
            }
        }
        writer.start()
        for i in 1...1000 {
            let reader = ThreadContext(name: "reader\(i)") {
                while true {
                    if let x = c.read() {
                        if x % 7 == 0 {
                            return
                        } else {
                            //  print("still going: \(ThreadContext.currentContext().name)")
                        }
                    } else {
                        // print("done with:\(ThreadContext.currentContext().name)")
                        return
                    }
                }
            }
            reader.start()
            readers.append(reader)
        }
        for reader in readers {
            var timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 10000)
            if reader.join(&timeoutAt) != 0 {
                XCTFail("should not get here, should have joined")
            }
        }
        for reader in readers {
            XCTAssertEqual(ThreadContext.ENDED, reader.state)
        }
    }

    public func testCloseSingleReader() throws {
        let latch = CountdownLatch(1)
        let c = ChannelFactory.AsAny.LLQ(max: 10).create(t: String.self)
        let writer = ThreadContext(name: "writer") {
            var timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 5000)
            latch.await(&timeoutAt)
            XCTAssertEqual(0, latch.get())
            for i in 1...100 {
                c.write("howdy doody: \(i)")
            }
            c.close()
        }
        writer.start()
        var cnt = 0
        let reader = ThreadContext(name: "reader") {
            while true {
                if let s = c.read() {
                    cnt += 1
                } else {
                    return
                }
            }
        }
        reader.start()
        latch.countDown()

        var timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 5000)
        reader.join(&timeoutAt)
        XCTAssertEqual(0, reader.join(&timeoutAt))
        XCTAssertEqual(100, cnt)
    }

    public func testClose500Readers() throws {
        let latch = CountdownLatch(1)
        let c = ChannelFactory.AsAny.LLQ(max: 10,
                writeLock: NonFairLock(1), readLock: NonFairLock(1000)).create(t: String.self)
        let writer = ThreadContext(name: "writer") {
            var timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 10000)
            latch.await(&timeoutAt)
            XCTAssertEqual(0, latch.get())
            for i in 1...487 {
                c.write("howdy doody: \(i)")
            }
            c.close()
        }
        writer.start()

        var readers: [ThreadContext] = []
        var cnt = ManagedAtomic<Int>(0)
        var i = 0
        while i < 500 {
            let reader = ThreadContext(name: "reader\(i)") {
                while true {
                    if let s = c.read() {
                        let cnt = cnt.wrappingIncrementThenLoad(ordering: .relaxed)
                    } else {
                        return
                    }
                }
            }
            reader.start()
            readers.append(reader)
            i += 1
        }
        latch.countDown()

        for reader in readers {
            var timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 5000)
            XCTAssertEqual(0, reader.join(&timeoutAt))
        }
        XCTAssertEqual(487, cnt.load(ordering: .relaxed))
    }

    /*
    public func testAsync() throws  {


        s1 = createStage( inputs("ch1"), outputs("ch2", "ch4"))  {  (ch1,ch2,ch4)->Void in {
            if let url = ch1.read() {
                do {
                if let response = try process(url)  {
                    ch2.write(response)
                    return true
                } catch {
                        ch4.write("problems with request to \(url)")
                    }
                }
            } else {
                return false
            }
        }

        pipeline = createPipeline(s1,s2,s3,s4)
        let stage1 = createStage( inputChannel, ) {
            if let response = client.makeRequest(input) {
                processHttpResponse.write(response)
            } else {
                completion.write("Error with \(input)")
            }

        }


        let ch1 = ChannelFactory.AsAny.LLQ(max: 10).create(t: String.self)
        let ch2 = ChannelFactory.AsAny.LLQ(max: 10).create(t: String.self)
        let ch3 = ChannelFactory.AsAny.LLQ(max: 10).create(t: String.self)

        let ch1Reader = ThreadContext("ch1Reader") {
            while true {
                if let input = ch1.read() {
                    if let response = client.makeRequest(input) {
                        ch2.write(response)
                    } else {
                        ch3.write()
                    }
                } else {
                    return
                }
            }
        }

        let ch2Reader = ThreadContext("ch2Reader") {
            while true {
                if let data =
            }
        }



        myJob(input, completionHandler) {

            data = client.call(input)

            resultB = processData(data)

            resultC = processAgain(resultB)

            finalResult = completeJob(resultC)
        }



    }
     */


    static var allTests = [
        ("testFoo", testFoo),
        ("testFull", testFull),
        ("testSingleValueStoreViaLLQ", testSingleValueStoreViaLLQ),
        ("testSingleValueStore", testSingleValueStore),
        ("testCloseSingleReader", testCloseSingleReader),
        ("testClose500Readers", testClose500Readers)
    ]
}


/*


   Channel                                   Selectable

       ----> NonSelectableChannel
                                              <---
                 --> SelectableChannel is! Selectable


                  AnyChannel    isSelectable
 */