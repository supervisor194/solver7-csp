import Foundation


public class TokenRequest: Equatable {

    public let num: Int
    public let respond: () -> Void

    public init(_ num: Int, _ respond: @escaping () -> Void) {
        self.num = num
        self.respond = respond
    }

    public static func ==(lhs: TokenRequest, rhs: TokenRequest) -> Bool {
        lhs === rhs
    }

}
