import Foundation

public protocol ReadableChannel {

    associatedtype Item

    func read() -> Item?

    func read(into: inout [Item?], upTo: Int) -> Void

    func numAvailable() -> Int
}
