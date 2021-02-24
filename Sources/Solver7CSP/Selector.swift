import Foundation

public protocol Selector {

    func select() -> Selectable

    func schedule() -> Void

    func setTimeoutAt(_ at: timespec)

}
