import Foundation

public class BarrierManager {

    let maxTokens: Int
    var available: Int

    /*
     Workers write TokenRequest objects using this writer,  Underlying Channel:  Many Writers to 1 Reader
     */
    let tokenRequestWriter: (TokenRequest) -> Void  // Workers are multiple writers
    let tokenRequestReader: () -> TokenRequest    // BarrierManager is single reader

    /*
     Workers write release requests (Int) using this writer, Underlying Channel: Many Writers to 1 Reader
     */
    let tokenReleaseWriter: (Int) -> Void  // Workers are multiple writers
    let tokenReleaseReader: () -> Int  // BarrierManager is single reader

    let workerPool : BarrierWorkerPool

    public init(maxTokens: Int,
                numWorkers: Int,
                taskChannel: AnyChannel<BarrierTask>,
                tokenRequestChannel: AnyChannel<TokenRequest>,
                tokenReleaseChannel: AnyChannel<Int>) {
        self.maxTokens = maxTokens
        available = maxTokens

        tokenRequestWriter = { (request) -> Void in
            tokenRequestChannel.write(request)
        }
        tokenRequestReader = { () -> TokenRequest in
            tokenRequestChannel.read()!
        }

        tokenReleaseWriter = { (release) -> Void in
            tokenReleaseChannel.write(release)
        }
        tokenReleaseReader = { () -> Int in
            tokenReleaseChannel.read()!
        }

        workerPool = BarrierWorkerPool(numWorkers: numWorkers, taskQ: taskChannel,
               tokenRequestWriter: tokenRequestWriter,
                tokenReleaseWriter: tokenReleaseWriter)


    }

    public func run() -> Void {
        while true {
            let request = tokenRequestReader()
            let numRequested = request.num
            while available < numRequested {
                let released = tokenReleaseReader()
                available += released
            }
            request.respond()
            available -= numRequested
        }
    }
}