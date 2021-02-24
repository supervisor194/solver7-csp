import Foundation

public class BarrierWorkerPool {

    let _numWorkers: Int

    public var barrier: Int {
        get {
            _numWorkers
        }
    }

    let taskQ: AnyChannel<Task>

    let tokenRequestWriter: (_ req: TokenRequest) -> Void
    let tokenReleaseWriter: (_ req: Int) -> Void

    init(numWorkers: Int,
         taskQ: AnyChannel<Task>,
         tokenRequestWriter: @escaping (_ req: TokenRequest) -> Void,
         tokenReleaseWriter: @escaping (_ req: Int) -> Void) {
        _numWorkers = numWorkers
        self.taskQ = taskQ
        self.tokenRequestWriter = tokenRequestWriter
        self.tokenReleaseWriter = tokenReleaseWriter
        createWorkers()
    }

    private func createWorkers() {
        for i in 1..._numWorkers {
            let w = BarrierWorker(taskQ: taskQ, tokenRequestWriter: tokenRequestWriter, tokenReleaseWriter: tokenReleaseWriter)
            let wTC = ThreadContext(name: "worker\(i)", execute: w.run)
            wTC.start()
        }
    }


}
