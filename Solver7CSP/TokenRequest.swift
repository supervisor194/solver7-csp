import Foundation


class TokenRequest: Equatable {

    public let num: Int
    public let respond: () -> Void

    init(_ num: Int, _ respond: @escaping () -> Void) {
        self.num = num
        self.respond = respond
    }

    static func ==(lhs: TokenRequest, rhs: TokenRequest) -> Bool {
        lhs === rhs
    }

}
