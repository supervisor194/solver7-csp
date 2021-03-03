import XCTest
@testable import Solver7CSP

import Foundation
import Dispatch
import Atomics

class PipelineTests: XCTestCase {

    public func testDispatchQueues() throws {

        let dqA = DispatchQueue(label: "A", attributes: .concurrent)
        let dqB = DispatchQueue(label: "B", attributes: .concurrent)
        let dqC = DispatchQueue(label: "C")

        let dA = BasicDispatcher(name: "A", df: { (t) -> Void in
            dqA.async(execute: t.f)
        })
        Dispatchers.instance.add(dispatcher: dA)
        let dB = BasicDispatcher(name: "B", df: { (t) -> Void in
            dqB.async(execute: t.f)
        })
        Dispatchers.instance.add(dispatcher: dB)
        let dC = BasicDispatcher(name: "C", df: { (t) -> Void in
            dqC.sync(execute: t.f)
        })
        Dispatchers.instance.add(dispatcher: dC)

        var d0 = Duration()
        d0.start()

        let l1 = try CountdownLatchViaChannel(1)
        SillyTaskC.GL = l1
        var i = 0
        while i < 1000000 {
            let tA = SillyTaskA(msg: "howdy doody")
            dA.dispatch(task: tA)
            i+=1
        }
        l1.await(TimeoutState.computeTimeoutTimespec(sec: 30, nanos:0 ))
        d0.stop()
        print("done :\(d0.milliseconds)")

        ////////////

        let taskQ1 = AnyChannel(NonSelectableChannel<String>(store: AnyStore(LinkedListQueue<String>(max: 1000))))
        let taskQ2 = AnyChannel(NonSelectableChannel<String>(store: AnyStore(LinkedListQueue<String>(max: 1000))))

        var d = Duration()
        d.start()

        let tc0 = ThreadContext(name: "tc0") {
            var i = 0
            while i<1000000 {
                taskQ1.write(" howdy \(i)")
                i+=1
            }
        }
        XCTAssertEqual(0, tc0.start())

        let r2 = { () -> Void in
            while true {
                var msgs : [String?] = []
                taskQ1.read(into: &msgs, upTo: 1000)
                let  s = msgs.count
                var i = 0
                while i < s {
                    taskQ2.write(msgs[i])
                    i+=1
                }
            }
        }
        let tc2 = ThreadContext(name: "tc2a", execute: r2)
        XCTAssertEqual(0, tc2.start())
        /*
        var tc2a = ThreadContext(name: "tc2b", execute: r2)
        tc2a.start()
        var tc2b = ThreadContext(name: "tc2c", execute: r2)
        tc2b.start()
        var tc2c = ThreadContext(name: "tc2d", execute: r2)
        tc2c.start()
         */
        let l2 = try CountdownLatchViaChannel(1)

        let r3 = { ()->Void in
            var cnt = 0
            while cnt < 1000000 {
                var msgs : [String?] = []
                taskQ2.read(into: &msgs, upTo: 1000)
                cnt+=msgs.count
            }
            // print("done r3")
            l2.countDown()
        }
        let tc3 = ThreadContext(name: "tc3", execute: r3)
        XCTAssertEqual(0, tc3.start())
        l2.await(TimeoutState.computeTimeoutTimespec(sec: 60, nanos: 0))
        d.stop()
        print("duration: \(d.milliseconds)")

    }

    static var allTests = [
        ("testB1", testDispatchQueues),

    ]
}


protocol SillyTask {

    var name: String { get }

    func f() -> Void

}

protocol Dispatcher {

    var name:String { get }

    func dispatch(task: SillyTask) -> Void

}

class BasicDispatcher : Dispatcher {

    let name: String
    let df: (SillyTask)->Void

    init(name: String, df: @escaping (SillyTask) -> Void ) {
        self.name = name
        self.df = df
    }

    func dispatch(task: SillyTask) {
        df(task)
    }
}

class Dispatchers {

    static let instance = { () -> Dispatchers in
        let dispatchers = Dispatchers()
        return dispatchers
    }()

    private init() {
    }

    var dispatchers : [ String: Dispatcher] = [:]

    func add(dispatcher: Dispatcher) {
       dispatchers[dispatcher.name] = dispatcher
    }

    func lookup(name:String) -> Dispatcher? {
        dispatchers[name]
    }

    func dispatch(task: SillyTask) -> Void {
        Dispatchers.instance.lookup(name: task.name)?.dispatch(task: task)
    }
}

class SillyTaskA : SillyTask  {

    static let name = "A"

    var name : String {
        get {
            SillyTaskA.name
        }
    }

    let msg:String

    init(msg: String) {
        self.msg = msg
    }

    func f() {
        let nextMsg = "\(msg) hello there"
        let nextTask = SillyTaskB(msg: nextMsg)
        Dispatchers.instance.dispatch(task: nextTask)
    }

}

class SillyTaskB : SillyTask  {

    static let name = "B"

    var name : String {
        get {
            SillyTaskB.name
        }
    }

    let msg:String

    init(msg: String) {
        self.msg = msg
    }

    func f() {
        let nextMsg = "\(msg) hello there"
        let nextTask = SillyTaskC(msg: nextMsg)
        Dispatchers.instance.dispatch(task: nextTask)
    }

}

class SillyTaskC : SillyTask  {

    static let name = "C"

    var name: String {
        get {
            SillyTaskC.name
        }
    }

    static var GL : CountdownLatchViaChannel? = nil

    let msg:String
    static var _cnt = 0
    var cnt : Int {
        get {
            SillyTaskC._cnt
        }
    }

    init(msg: String) {
        self.msg = msg
    }

    func f() {
        SillyTaskC._cnt += 1
        if SillyTaskC._cnt == 1000000 {
            SillyTaskC.GL?.countDown()
        }
    }

}


