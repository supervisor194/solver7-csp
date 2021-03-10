import Foundation
import XCTest

@testable import Solver7CSP


extension ChannelFactory {

    enum Mine: ChannelCreator {
        case NSLLQ100
        case NSRWLLQ100

        public func create<T: Equatable>(t: T.Type) -> AnyChannel<T> {
            switch self {
            case .NSLLQ100:
                return AnyChannel(NonSelectableChannel(store: AnyStore(LinkedListQueue<T>(max: 100))))
            case .NSRWLLQ100:
                return AnyChannel(NonSelectableChannel(store: AnyStore(LinkedListQueue<T>(max: 100))))
            }
        }
    }
}


class FactoryTest: XCTestCase {

    public func testOne() throws {

        let x = ChannelFactory.AsAny.LLQ(max: 10).create(t: String.self)
        let sx = ChannelFactory.AsAny.SLLQ(id: "MySelectableChannel", max: 10).create(t: String.self)
        let y = ChannelFactory.AsAny.SVS().create(t: String.self)

        let zz = ChannelFactory.Mine.NSLLQ100.create(t: Int.self)
        let z2 = ChannelFactory.Mine.NSRWLLQ100.create(t: Int.self)

        let sc = ChannelFactory.AsSelectable.SLLQ(id: "s1", max: 10).create(t: Int.self)

        let scAsAny = AnyChannel(sc)

        XCTAssertTrue(scAsAny.isSelectable())
        XCTAssertNotNil(scAsAny.selectable)

        let sc2 : SelectableChannel<Int> = scAsAny.selectable!
        XCTAssertNotNil(sc2)

        var channels : [AnyChannel<Int>] = []

        channels.append(z2)
        channels.append(scAsAny)
        channels.append(zz)

        XCTAssertEqual(3, channels.count)

        for ch in channels {
            if ch.isSelectable() {
                XCTAssertNotNil(ch.selectable)
            } else {
                XCTAssertNil(ch.selectable)
            }
        }
    }

    public func testStoreCreationOfLLQ() throws  {
        let llq = StoreFactory.AsAny.LLQ(max: 10).create(t: Int.self)
        XCTAssertEqual(10, llq.max)
        XCTAssertEqual(0, llq.count)
        llq.put(3)
        XCTAssertEqual(1, llq.count)
        let x = llq.get()!
        XCTAssertEqual(3,x)
        XCTAssertEqual(0, llq.count)
    }

    public func testStoreCreationOfSVS() throws  {
        let svs = StoreFactory.AsAny.SVS.create(t: Int.self)
        XCTAssertEqual(1, svs.max)
        XCTAssertEqual(0, svs.count)
        svs.put(3)
        XCTAssertEqual(1, svs.count)
        let x = svs.get()!
        XCTAssertEqual(3,x)
        XCTAssertEqual(0, svs.count)
    }

    public func testSelectables() throws  {

        var selectables: [Selectable] = []
        var channels: [AnyChannel<Int>] = []

        var sum = 0

        for i in 1...10 {
            let selectable = ChannelFactory.AsSelectable.SLLQ(id: "\(i)", max: 10).create(t: Int.self)
            selectable.setHandler() {
                sum += selectable.read()!
            }
            selectables.append(selectable)
            channels.append(AnyChannel<Int>(selectable as! SelectableChannel))
        }

        var done = false

        let t1 = Timeout<String>(id: "t1")
        var x = 0
        let lt1 = try CountdownLatch(10)
        t1.setHandler() {
            if lt1.get() > 0 {
                t1.setTimeout(TimeoutState.computeTimeoutTimespec(millis: 500))
                lt1.countDown()
            } else {
                done = true
            }
        }
        t1.setTimeout(TimeoutState.computeTimeoutTimespec(millis: 1000))

        let t2 = Timeout<String>(id: "t2")
        var y = 0
        let lt2 = try CountdownLatch(5)
        t2.setHandler() {
            if lt2.get() > 0 {
                t2.setTimeout(TimeoutState.computeTimeoutTimespec(millis: 100))
                lt2.countDown()
            }
        }
        t2.setTimeout(TimeoutState.computeTimeoutTimespec(millis: 1000))

        selectables.append(t1)
        selectables.append(t2)

        let lw = try CountdownLatch(10)
        for w in 1...10 {
            let writer = ThreadContext(name: "w:\(w)") {
                for j in 0...9 {
                    channels[j].write(j)
                }
                lw.countDown()
            }
            writer.start()
        }

        let fs = try FairSelector(selectables)

        while !done {
            let s = fs.select()
            s.handle()
        }

        // sum should be == (0+9) * (10/2) * 10 --> 9 * 5 * 10 --> 450
        XCTAssertEqual(450, sum)
        XCTAssertEqual(0, lw.get())
        XCTAssertEqual(0, lt1.get())
        XCTAssertEqual(0, lt2.get())

    }

    static var allTests = [
        ("testOne", testOne),
        ("testStoreCreationOfLLQ", testStoreCreationOfLLQ),
        ("testStoreCreationOfSVS", testStoreCreationOfSVS),
        ("testSelectables", testSelectables),
    ]
}
