import Foundation

public protocol Lock {

    func lock() -> Void

    func unlock() -> Void

    func doWait() -> Void

    func doWait(_ timeoutAt: inout timespec) -> Void

    func doNotify() -> Void

    func reUp() -> Void
}
