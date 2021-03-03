import Foundation

public class BarrierWorkerPool {

    let _numWorkers: Int

    public var barrier: Int {
        get {
            _numWorkers
        }
    }

    let taskQ: AnyChannel<BarrierTask>

    let tokenRequestWriter: (_ req: TokenRequest) -> Void
    let tokenReleaseWriter: (_ req: Int) -> Void

    public init(numWorkers: Int,
         taskQ: AnyChannel<BarrierTask>,
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
            let status = wTC.start()
            if status != 0 {
                fatalError("Could not start worker: \(wTC.name), status == \(status)")
            }
        }
    }


}
