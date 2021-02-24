import Foundation

class BarrierManager {

    let max: Int
    var available: Int
    let requestReader: () -> TokenRequest
    let releaseReader: () -> Int

    init(max: Int, tokenRequestReader: @escaping () -> TokenRequest,
         tokenReleaseReader: @escaping () -> Int) {
        self.max = max
        available = max
        requestReader = tokenRequestReader
        releaseReader = tokenReleaseReader
    }

    public func run() -> Void {
        while true {
            let request = requestReader()
            let numRequested = request.num
            while available < numRequested {
                let released = releaseReader()
                available += released
            }
            request.respond()
            available -= numRequested
        }
    }
}