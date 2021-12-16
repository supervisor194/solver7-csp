import Foundation

public class BarrierManager {

    let maxTokens: Int
    var available: Int

    /*
     Workers write TokenRequest objects using this writer,  Underlying Channel:  Many Writers to 1 Reader
     */
    let tokenRequestWriter: (TokenRequest) throws -> Void  // Workers are multiple writers
    let tokenRequestReader: () throws -> TokenRequest    // BarrierManager is single reader

    /*
     Workers write release requests (Int) using this writer, Underlying Channel: Many Writers to 1 Reader
     */
    let tokenReleaseWriter: (Int) throws -> Void  // Workers are multiple writers
    let tokenReleaseReader: () throws -> Int  // BarrierManager is single reader

    let workerPool: BarrierWorkerPool

    public init(maxTokens: Int,
                numWorkers: Int,
                taskChannel: AnyChannel<BarrierTask>,
                tokenRequestChannel: AnyChannel<TokenRequest>,
                tokenReleaseChannel: AnyChannel<Int>) {
        self.maxTokens = maxTokens
        available = maxTokens

        tokenRequestWriter = { (request) throws -> Void in
            try tokenRequestChannel.write(request)
        }
        tokenRequestReader = { () throws -> TokenRequest in
            try tokenRequestChannel.read()!
        }

        tokenReleaseWriter = { (release) throws -> Void in
            try tokenReleaseChannel.write(release)
        }
        tokenReleaseReader = { () throws -> Int in
            try tokenReleaseChannel.read()!
        }

        workerPool = BarrierWorkerPool(numWorkers: numWorkers, taskQ: taskChannel,
                tokenRequestWriter: tokenRequestWriter,
                tokenReleaseWriter: tokenReleaseWriter)


    }

    public func run() -> Void {
        do {
            while true {
                let request = try tokenRequestReader()
                let numRequested = request.num
                while available < numRequested {
                    let released = try tokenReleaseReader()
                    available += released
                }
                try request.respond()
                available -= numRequested
            }
        } catch {

        }
    }
}