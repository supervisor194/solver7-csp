import Foundation


public class BarrierWorker {

    let taskQ: AnyChannel<Task>

    let tokenRequestWriter: (_ req: TokenRequest) -> Void
    let tokenReleaseWriter: (_ req: Int) -> Void
    let tokenResponseQ: NonSelectableChannel<Int>

    init(taskQ: AnyChannel<Task>,
         tokenRequestWriter: @escaping (TokenRequest) -> Void,
         tokenReleaseWriter: @escaping (Int) -> Void) {
        self.taskQ = taskQ
        self.tokenRequestWriter = tokenRequestWriter
        self.tokenReleaseWriter = tokenReleaseWriter
        let llq = LinkedListQueue<Int>(max: 2)
        let s = AnyStore<Int>(llq)
        tokenResponseQ = NonSelectableChannel<Int>(store: s, lockType: LockType.NON_FAIR_LOCK)
    }

    public func run() -> Void {
        while true {
            let task = taskQ.read()!
            getTokens(task)
            // print("worker: \(Unmanaged.passUnretained(self).toOpaque()), calling handle()...")
            task.handle()
            tokenReleaseWriter(task.numTokens)
        }
    }

    func getTokens(_ task: Task) {
        let tokenRequest = TokenRequest(task.numTokens, { () -> Void in
            // todo: maybe not use closure ???
            self.tokenResponseQ.write(task.numTokens)
        })
        tokenRequestWriter(tokenRequest)
        tokenResponseQ.read()
    }

}