import XCTest
@testable import Solver7CSP

import Foundation

class LinkedListQueueTests: XCTestCase {


    func testManyWritersSingleReader() throws  {


        let latch = try CountdownLatch(11) // 10 writers, 1 reader
        let c = NonSelectableChannel(store: AnyStore( LinkedListQueue<String> (max: 10)))

        for i in 1...10 {
            let writer = ThreadContext(name: "writer\(i)") {
                for n in 1...100 {
                    c.write("writer\(i) message #\(n)")
                }
                latch.countDown()
            }
            writer.start()
        }

        var cnt = 0
        for i in 1...1 {
            let reader = ThreadContext(name: "reader\(i)") {
                while true {
                    c.read()
                    cnt += 1
                    if (cnt == 1000) {
                        latch.countDown()
                        return
                    }
                }
            }
            reader.start()
        }

        latch.await(TimeoutState.computeTimeoutTimespec(millis: 3000))

        XCTAssertEqual(0, latch.get())
        XCTAssertEqual(1000, cnt)

    }
    func testAll() {

        let q = LinkedListQueue<MyInt64>(max: 100)
        XCTAssertEqual(100, q.max)
        XCTAssertTrue(q.isEmpty())
        XCTAssertFalse(q.isFull())
        XCTAssertEqual(0, q.count)
        XCTAssertEqual(StoreState.EMPTY, q.state)
        var num = q.put(MyInt64(100))
        q.put(MyInt64(1110))
        XCTAssertEqual(StoreState.NONEMPTY, q.state)
        XCTAssertEqual(2, q.count)
        XCTAssertEqual(100, q.take()?.val)
        XCTAssertEqual(1110, q.take()?.val)
        XCTAssertEqual(0, q.count)
        let x = MyInt64(9999)
        q.put(MyInt64(77))
        q.put(x)
        q.put(MyInt64(99))
        let b = q.remove(x)
        XCTAssertTrue(b)
        XCTAssertEqual(77, q.take()?.val)
        XCTAssertEqual(99, q.take()?.val)
        q.put(nil)
        XCTAssertEqual(1, q.count)
        if let a = q.take() {
            XCTFail("should not get here")
        }
        q.put(nil)
        if let b = q.take() {
            XCTFail("should not get here")
        }
        XCTAssertEqual(0, q.count)

        for i in 1...110 {
            if(!q.isFull()) {
                q.put(MyInt64(Int64(i)))
            }
        }
        XCTAssertEqual(100, q.count)
        XCTAssertEqual(StoreState.FULL, q.state)
        q.clear()
        XCTAssertEqual(0, q.count)
        XCTAssertTrue(q.isEmpty())
        XCTAssertFalse(q.isFull())
    }
    static var allTests = [
        ("testAll", testAll),
    ]
}


class MyInt64: Equatable {
    let _val: Int64

    var val: Int64 {
        get {
            return _val
        }
    }

    init(_ val: Int64) {
        self._val = val
    }

    static func ==(lhs: MyInt64, rhs: MyInt64) -> Bool {
        lhs===rhs
    }
}
