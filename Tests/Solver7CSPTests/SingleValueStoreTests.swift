import Foundation
import XCTest

@testable import Solver7CSP

class SingleValueStoreTests : XCTestCase {


    public func testAll() throws {
        // W writers --> single value store --> R readers/writers --> 1 reader check count

        let N = 5000
        let W = 13
        let R = 15

        let ch = ChannelFactory.Default.SVS(writeLock: NonFairLock(W), readLock: NonFairLock(R)).create(t: Int.self)
        for i in 1...W {
            let w = ThreadContext(name: "writer:\(i)") {
                var x = 1
                while x <= N {
                    ch.write(x)
                    x+=1
                }
            }
            w.start()
        }

        let ch2 = ChannelFactory.Default.SVS(writeLock: NonFairLock(R), readLock: NonFairLock(1)).create(t: Int.self)
        for i in 1...R {
            let r = ThreadContext(name: "reader:\(i)") {
                while true {
                    let x = ch.read()!
                    ch2.write(x)
                }
            }
            r.start()
        }

        let S = ( (1+N) * N/2 ) * W
        let latch = CountdownLatch(1)
        let adder = ThreadContext(name: "adder") {
            var sum = 0
            while sum < S {
                sum += ch2.read()!
            }
            XCTAssertEqual(S, sum)
            latch.countDown()
        }
        adder.start()

        var timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 33000)
        latch.await(&timeoutAt)

        XCTAssertEqual(0, ch.numAvailable())
        XCTAssertEqual(0, ch2.numAvailable())

    }
}
