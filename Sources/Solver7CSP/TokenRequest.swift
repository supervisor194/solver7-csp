import Foundation


public class TokenRequest: Equatable {

    public let num: Int
    public let respond: () throws -> Void

    public init(_ num: Int, _ respond: @escaping () throws -> Void) {
        self.num = num
        self.respond = respond
    }

    public static func ==(lhs: TokenRequest, rhs: TokenRequest) -> Bool {
        lhs === rhs
    }

}
