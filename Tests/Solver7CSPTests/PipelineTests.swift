import XCTest
@testable import Solver7CSP

import Foundation
import Dispatch
import Atomics

class PipelineTests: XCTestCase {

    public func testStage() throws {

        let ch1 = ChannelFactory.AsAny.LLQ(id: "ch1", max: 10).create(t: String.self)
        let ch2 = ChannelFactory.AsAny.LLQ(id: "ch2", max: 10).create(t: String.self)
        let ch3 = ChannelFactory.AsAny.LLQ(id: "ch3", max: 10).create(t: String.self)
        let ch4 = ChannelFactory.AsAny.LLQ(id: "ch4", max: 10).create(t: String.self)

        let stage0TC = ThreadContext(name: "stage0") {
         do {
            try ch1.write("hello1")
            try ch1.write("skip")
            try ch1.write("hello2")
            try ch1.write("stage0 done")
            } catch {
                XCTFail("problems with writes")
            }

        }
        let stage0 = Stage(name: "stage0", inputs: [], outputs: [ch1], tc: stage0TC)
        stage0TC.start()

        let stage1TC = ThreadContext(name: "stage1") {
            do {
                while true {
                    if let x = try ch1.read() {
                        if x == "skip" {
                            try ch3.write(x + " skipped")
                        } else {
                            try ch2.write(x + " added by stage1")
                        }
                    }
                }
            } catch {
                do {
                    try ch2.write("stage1 done")
                } catch {
                    XCTFail("Should be able to write to ch2")
                }
                ch2.close()
            }
        }
        let stage1 = Stage(name: "stage1", inputs: [ch1], outputs: [ch2, ch4], tc: stage1TC)
        stage1TC.start()

        let stage2TC = ThreadContext(name: "stage2") {
            do {
                while true {
                    if let x = try ch2.read() {
                        try ch3.write(x + " added by stage2")
                    } else {

                        return
                    }
                }
            } catch {
                do {
                    try ch3.write("stage2 done")
                } catch {
                    XCTFail("Shoudl be able to write to ch3")
                }
                ch3.close()
            }
        }
        let stage2 = Stage(name: "stage2", inputs: [ch2], outputs: [ch3], tc: stage2TC)
        stage2TC.start()

        let stage3TC = ThreadContext(name: "stage3") {
            do {
                while true {
                    if let x = try ch3.read() {
                        try ch4.write(x + " added by stage3")
                    }
                }
            } catch {
                do {
                    try  ch4.write("stage3 done")
                } catch {
                    XCTFail("Should be able to write to ch4")
                }
                ch4.close()
            }
        }
        let stage3 = Stage(name: "stage3", inputs: [ch3], outputs: [ch4], tc: stage3TC)
        stage3TC.start()

        var output: [String] = []

        let stage4TC = ThreadContext(name: "stage4") {
            do {
                while true {
                    if let x = try ch4.read() {
                        output.append(x)
                    }
                }
            } catch {
                output.append("stage4 done")
                ch4.close()
            }
        }
        let stage4 = Stage(name: "stage4", inputs: [ch4], outputs: [], tc: stage4TC)
        stage4TC.start()

        let pipeline = Pipeline()

        pipeline.add(stage: stage1)
        pipeline.add(stage: stage3)
        pipeline.add(stage: stage2)
        pipeline.add(stage: stage0)
        pipeline.add(stage: stage4)

        pipeline.build()
        pipeline.sortTopologically()

        var to: [String] = []
        try pipeline.dfs(callback: { (v) -> Bool in
            to.append(v.name)
            return true
        })

        var i = 0
        for s in to.reversed() {
            XCTAssertEqual(s, pipeline.topologicalOrder[i].name)
            i += 1
        }


        var timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 100000)
        let closeResult = pipeline.close(timeoutAt: &timeoutAt)
        XCTAssertEqual(0, closeResult)

        let expected: [String] = [
            "skip skipped added by stage3",
            "hello1 added by stage1 added by stage2 added by stage3",
            "hello2 added by stage1 added by stage2 added by stage3",
            "stage0 done added by stage1 added by stage2 added by stage3",
            "stage1 done added by stage2 added by stage3",
            "stage2 done added by stage3",
            "stage3 done",
            "stage4 done",
        ]

        i = 0
        for s in output {
            XCTAssertEqual(expected[i], s)
            i+=1
        }

        XCTAssertEqual(0, ch1.numAvailable())
        XCTAssertEqual(0, ch2.numAvailable())
        XCTAssertEqual(0, ch3.numAvailable())
        XCTAssertEqual(0, ch4.numAvailable())

        XCTAssertTrue(ch1.isClosed())
        XCTAssertTrue(ch2.isClosed())
        XCTAssertTrue(ch3.isClosed())
        XCTAssertTrue(ch4.isClosed())
    }

    public func testManyWritersManyReaders() throws {
        // W writers for N*W msgs --> 2*W channels --> W selectable readers/writers -->
        //     2 channels --> 2 readers/writers --> 1 channel --> 1 reader --> cnt == N*W

        let N = 5
        let W = 10
        let UW2 = UInt64(W * 2)
        let l1 = CountdownLatch(W)
        var level1Channels: [SelectableChannel<Int>] = []
        for i in 1...W {
            level1Channels.append(ChannelFactory.AsSelectable.SLLQ(id: "level1:\(i)", max: 100,
                    writeLock: NonFairLock(2 * W), readLock: NonFairLock(1)).create(t: Int.self))
            level1Channels.append(ChannelFactory.AsSelectable.SSVS(id: "level1b:\(i)",
                    writeLock: NonFairLock(2 * W), readLock: NonFairLock(1)).create(t: Int.self))
        }
        var rng = SystemRandomNumberGenerator()
        for i in 1...W {
            let writer = ThreadContext(name: "initiator:\(i)") {
                var x = 1
                do {
                    while x <= N {
                        let ch = Int(rng.next() % UW2)
                        try level1Channels[ch].write(x)
                        x += 1
                    }
                    l1.countDown()
                } catch {
                    XCTFail("problems with writer")
                }
            }
            writer.start()
        }

        let io1 = ChannelFactory.AsAny.LLQ(max: 10, writeLock: NonFairLock(W), readLock: NonFairLock(1)).create(t: Int.self)
        let io2 = ChannelFactory.AsAny.LLQ(max: 10, writeLock: NonFairLock(W), readLock: NonFairLock(1)).create(t: Int.self)

        for i in 1...W {
            let reader = ThreadContext(name: "R1:\(i)") {
                var selectables: [Selectable] = []
                let ch1 = level1Channels[(i - 1) * 2]
                let ch2 = level1Channels[(i - 1) * 2 + 1]
                ch1.setHandler() {
                    do {
                        try io1.write(try ch1.read())
                    } catch {
                        XCTFail("problems with write/read")
                    }
                }
                ch2.setHandler() {
                    do {
                        try io2.write(try ch2.read())
                    } catch {
                        XCTFail("problems with ch2")
                    }
                }
                selectables.append(ch1)
                selectables.append(ch2)

                let selector: Solver7CSP.Selector
                do {
                    selector = try FairSelector(selectables)
                } catch {
                    XCTFail("problems with selector")
                    return
                }
                while true {
                    let s = selector.select()
                    s.handle()
                }
            }
            reader.start()
        }

        let output = ChannelFactory.AsAny.SVS().create(t: Int.self)
        let io1Reader = ThreadContext(name: "IO1Reader") {
            do {
                while true {
                    let val = try io1.read()
                    try output.write(val)
                }
            } catch {
                XCTFail("problems with io1Reader")
            }
        }
        io1Reader.start()

        let io2Reader = ThreadContext(name: "IO1Reader") {
            do {
                while true {
                    let val = try io2.read()
                    try output.write(val)
                }
            } catch {
                XCTFail("problems with io2Reader")
            }
        }
        io2Reader.start()

        let l2 = CountdownLatch(1)
        var cnt = 0
        let outputReader = ThreadContext(name: "OutputReader") {
            do {
                while cnt < N * W {
                    let val = try output.read()!
                    cnt += 1
                }
                l2.countDown()
            } catch {
                XCTFail("problems with outputReader")
            }
        }
        outputReader.start()


        var timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 5000)
        l1.await(&timeoutAt)
        XCTAssertEqual(0, l1.get())

        timeoutAt = TimeoutState.computeTimeoutTimespec(millis: 5000)
        l2.await(&timeoutAt)
        XCTAssertEqual(0, l2.get())
        XCTAssertEqual(N * W, cnt)

        for i in 0...level1Channels.count - 1 {
            XCTAssertEqual(0, level1Channels[i].numAvailable())
        }
        XCTAssertEqual(0, io1.numAvailable())
        XCTAssertEqual(0, io2.numAvailable())
        XCTAssertEqual(0, output.numAvailable())
    }


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

        let l1 = try CountdownLatch2(1)
        SillyTaskC.GL = l1
        var i = 0
        while i < 1000000 {
            let tA = SillyTaskA(msg: "howdy doody")
            dA.dispatch(task: tA)
            i += 1
        }
        l1.await(TimeoutState.computeTimeoutTimespec(sec: 30, nanos: 0))
        d0.stop()
        print("done :\(d0.milliseconds)")

        ////////////


        let taskQ1 = AnyChannel(NonSelectableChannel<String>(store: StoreFactory.AsAny.LLQ(max: 1000).create(t: String.self)))
        let taskQ2 = AnyChannel(NonSelectableChannel<String>(store: AnyStore(LinkedListQueue<String>(max: 1000))))

        var d = Duration()
        d.start()

        let tc0 = ThreadContext(name: "tc0") {
            var i = 0
            do {
                while i < 1000000 {
                    try taskQ1.write(" howdy \(i)")
                    i += 1
                }
            } catch {
                XCTFail("problems with tc0")
            }
        }
        XCTAssertEqual(0, tc0.start())

        let r2 = { () -> Void in
            while true {
                do {
                    var msgs: [String?] = []
                    try taskQ1.read(into: &msgs, upTo: 1000)
                    let s = msgs.count
                    var i = 0
                    while i < s {
                        try taskQ2.write(msgs[i])
                        i += 1
                    }
                } catch {
                    XCTFail("problems with r2")
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
        let l2 = try CountdownLatch2(1)

        let r3 = { () -> Void in
            var cnt = 0
            do {
                while cnt < 1000000 {
                    var msgs: [String?] = []
                    try taskQ2.read(into: &msgs, upTo: 1000)
                    cnt += msgs.count
                }
                try l2.countDown()
            } catch {
                XCTFail("problems with r3")
            }
        }
        let tc3 = ThreadContext(name: "tc3", execute: r3)
        XCTAssertEqual(0, tc3.start())
        l2.await(TimeoutState.computeTimeoutTimespec(sec: 60, nanos: 0))
        d.stop()
        print("duration: \(d.milliseconds)")

    }

    static var allTests = [
        ("testManyWritersManyReaders", testManyWritersManyReaders),
        ("testDispatchQueues", testDispatchQueues),
    ]
}


protocol SillyTask {

    var name: String { get }

    func f()  -> Void

}

protocol Dispatcher {

    var name: String { get }

    func dispatch(task: SillyTask) -> Void

}

class BasicDispatcher: Dispatcher {

    let name: String
    let df: (SillyTask) -> Void

    init(name: String, df: @escaping (SillyTask) -> Void) {
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

    var dispatchers: [String: Dispatcher] = [:]

    func add(dispatcher: Dispatcher) {
        dispatchers[dispatcher.name] = dispatcher
    }

    func lookup(name: String) -> Dispatcher? {
        dispatchers[name]
    }

    func dispatch(task: SillyTask) -> Void {
        Dispatchers.instance.lookup(name: task.name)?.dispatch(task: task)
    }
}

class SillyTaskA: SillyTask {

    static let name = "A"

    var name: String {
        get {
            SillyTaskA.name
        }
    }

    let msg: String

    init(msg: String) {
        self.msg = msg
    }

    func f() {
        let nextMsg = "\(msg) hello there"
        let nextTask = SillyTaskB(msg: nextMsg)
        Dispatchers.instance.dispatch(task: nextTask)
    }

}

class SillyTaskB: SillyTask {

    static let name = "B"

    var name: String {
        get {
            SillyTaskB.name
        }
    }

    let msg: String

    init(msg: String) {
        self.msg = msg
    }

    func f() {
        let nextMsg = "\(msg) hello there"
        let nextTask = SillyTaskC(msg: nextMsg)
        Dispatchers.instance.dispatch(task: nextTask)
    }

}

class SillyTaskC: SillyTask {

    static let name = "C"

    var name: String {
        get {
            SillyTaskC.name
        }
    }

    static var GL: CountdownLatch2? = nil

    let msg: String
    static var _cnt = 0
    var cnt: Int {
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
            do {
                try SillyTaskC.GL?.countDown()
            } catch {
                XCTFail("problems with sillytaskC")
            }
        }
    }

}


