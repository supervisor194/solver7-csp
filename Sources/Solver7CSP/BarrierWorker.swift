import Foundation


public class BarrierWorker {

    let taskQ: AnyChannel<BarrierTask>

    let tokenRequestWriter: (_ req: TokenRequest) throws -> Void
    let tokenReleaseWriter: (_ req: Int) throws -> Void
    let tokenResponseQ: NonSelectableChannel<Int>

    init(taskQ: AnyChannel<BarrierTask>,
         tokenRequestWriter: @escaping (TokenRequest) throws -> Void,
         tokenReleaseWriter: @escaping (Int) throws -> Void) {
        self.taskQ = taskQ
        self.tokenRequestWriter = tokenRequestWriter
        self.tokenReleaseWriter = tokenReleaseWriter
        let llq = LinkedListQueue<Int>(max: 2)
        let s = AnyStore<Int>(llq)
        tokenResponseQ = NonSelectableChannel<Int>(store: s)
    }

    public func run() -> Void {
        do {
            while true {
                let task = try taskQ.read()!
                getTokens(task)
                // print("worker: \(Unmanaged.passUnretained(self).toOpaque()), calling handle()...")
                task.handle()
                try tokenReleaseWriter(task.numTokens)
            }
        } catch {

        }
    }

    func getTokens(_ task: BarrierTask) {
        let tokenRequest = TokenRequest(task.numTokens, { () -> Void in
            // todo: maybe not use closure ???
            try self.tokenResponseQ.write(task.numTokens)
        })
        do {
            try tokenRequestWriter(tokenRequest)
            try tokenResponseQ.read()
        } catch {

        }
    }

}