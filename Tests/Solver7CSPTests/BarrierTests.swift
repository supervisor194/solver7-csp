import Foundation
import XCTest
@testable import Solver7CSP

class BarrierTests: XCTestCase {


    public func test5Workers() throws {


        let taskStore = AnyStore(LinkedListQueue<BarrierTask>(max: 100))
        let taskChannel = AnyChannel(NonSelectableChannel<BarrierTask>(store: taskStore))

        let requestReaderStore = AnyStore(LinkedListQueue<TokenRequest>(max: 100))
        let tokenRequestChannel = AnyChannel(NonSelectableChannel<TokenRequest>(store: requestReaderStore))

        let releaseReaderStore = AnyStore(LinkedListQueue<Int>(max: 100))
        let tokenReleaseChannel = AnyChannel(NonSelectableChannel<Int>(store: releaseReaderStore))

        let manager = BarrierManager(maxTokens: 5, numWorkers: 5, taskChannel: taskChannel,
                tokenRequestChannel: tokenRequestChannel,
                tokenReleaseChannel: tokenReleaseChannel)

        let mTC = ThreadContext(name: "BarrierManager", execute: manager.run)
        XCTAssertEqual(0, mTC.start())

        let latch = try CountdownLatch2(1)
        try taskChannel.write(BarrierTask(uuid: UUID.init(), numTokens: 1) { () -> Void in
            print("hello there, i'm task 1")
            do {
                try latch.countDown()
            } catch {
                XCTFail("problems with latch countdown")
            }
        })

        latch.await(TimeoutState.computeTimeoutTimespec(millis: 3000))
        XCTAssertEqual(0, latch.get())

        var val = 0

        let latch2 = try CountdownLatch2(1)
        let latch3 = try CountdownLatch2(1)

        try taskChannel.write(BarrierTask(uuid: UUID.init(), numTokens: 1) { () -> Void in
            print("i'm a delaying task")
            latch2.await(TimeoutState.computeTimeoutTimespec(millis: 5000))
            XCTAssertEqual(0, latch2.get())
            val = 7
        })
        try taskChannel.write(BarrierTask(uuid: UUID.init(), numTokens: 5) { () -> Void in
            print("i should have waited on the delaying task to release a token so i can get 5")
            XCTAssertEqual(7, val)
            val = 77
            do {
                try latch3.countDown()
            } catch {
                XCTFail("problems with latch countdown")
            }
        })

        sleep(1)
        try latch2.countDown()
        latch3.await(TimeoutState.computeTimeoutTimespec(millis: 5000))
        XCTAssertEqual(0, latch3.get())
        XCTAssertEqual(77, val)
    }

    static var allTests = [
        ("test5Workers", test5Workers),
    ]
}
