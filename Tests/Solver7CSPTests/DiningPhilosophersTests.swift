import Foundation
import XCTest
@testable import Solver7CSP

class DiningPhilosophersTests  : XCTestCase {

    static var allTests = [
        ("testFoo", testFoo),
    ]

    public func testFoo() throws  {

        let exitRequests = AnyChannel(NonSelectableChannel(store: AnyStore(LinkedListQueue<String>(max: 5))))
        let availableEnterTokens = AnyChannel(NonSelectableChannel(store: AnyStore(LinkedListQueue<String>(max: 5))))

        let porter = Porter(exitRequests: exitRequests, availableEnterTokens: availableEnterTokens)
        let porterTC = ThreadContext(name: "porter", execute: porter.run)
        XCTAssertEqual(0, porterTC.start())

        var chopstick : [AnyChannel<String>] = []

        for _ in 1...5 {
            chopstick.append(AnyChannel(NonSelectableChannel(store: AnyStore(LinkedListQueue<String>(max: 2)))))
        }


        let wantToSleep = try CountdownLatch2(5)

        for i in 0...4 {
            let p = Philosopher(id: "Philosopher:\(i)", myChopstick: chopstick[i], otherChopstick: chopstick[(i+1)%5],
                    exitRequests: exitRequests, availableEnterTokens: availableEnterTokens,
                    wantsToSleep: wantToSleep)
            let pTC = ThreadContext(name: p.getName(), execute: p.run)
            XCTAssertEqual(0, pTC.start())
        }

        for i in 0...4 {
            try chopstick[i].write("available")
        }

        wantToSleep.await(TimeoutState.computeTimeoutTimespec(millis: 60000))

        XCTAssertEqual(0, wantToSleep.get())

        let numAvailable = availableEnterTokens.numAvailable()
        XCTAssertEqual(4, numAvailable)
    }
}

class Philosopher {
    let id: String

    var mealsToEat = 10

    let myChopstick: AnyChannel<String>
    let otherChopstick: AnyChannel<String>

    let exitRequests: AnyChannel<String>
    let availableEnterTokens: AnyChannel<String>

    let wantsToSleep: CountdownLatch2

    init(id: String, myChopstick: AnyChannel<String>, otherChopstick: AnyChannel<String>,
         exitRequests: AnyChannel<String>, availableEnterTokens: AnyChannel<String>,
         wantsToSleep: CountdownLatch2) {
        self.id = id
        self.myChopstick = myChopstick
        self.otherChopstick = otherChopstick
        self.exitRequests = exitRequests
        self.availableEnterTokens = availableEnterTokens
        self.wantsToSleep = wantsToSleep
    }

    func getName() -> String {
        id
    }

    func think() -> Void {
        print("\(id) is thinking")
        Philosopher._pause()
    }

    func dine() throws -> Void {
        print("\(id) is trying to get two chopsticks to dine")
        try myChopstick.read()
        try otherChopstick.read()

        print("\(id) has two chopsticks, dining on meal: \(11 - mealsToEat) of 10")
        mealsToEat -= 1
        Philosopher._pause()

        try otherChopstick.write("available")
        try myChopstick.write("available")

    }

    func enter() throws -> Void {
        try availableEnterTokens.read()
    }

    func exit() throws -> Void {
        try exitRequests.write("make available")
    }

    func run() -> Void {
        do {
            while mealsToEat > 0 {
                think()
                try enter()
                try dine()
                try exit()
            }
            print("\(id) is done thinking and easting, going to bed!")
            try wantsToSleep.countDown()
        } catch {
            print("problems with philosopher")
        }
    }

    static var rng = SystemRandomNumberGenerator()

    static func _pause() {
        let usec = UInt32(rng.next() % 1000 * 1000)
        usleep(usec)
    }


}
class Porter {

    let exitRequests: AnyChannel<String>
    let availableEnterTokens: AnyChannel<String>

    init(exitRequests: AnyChannel<String>, availableEnterTokens: AnyChannel<String>) {
        self.exitRequests = exitRequests
        self.availableEnterTokens = availableEnterTokens
    }

    public func run() {
        // setup 4 available tokens
        do {
            for i in 1...4 {
                try exitRequests.write("\(i)")
            }

            while true {
                let token = try exitRequests.read()
                try availableEnterTokens.write(token)
            }
        } catch {
            print("problems with porter")
        }
    }


}
