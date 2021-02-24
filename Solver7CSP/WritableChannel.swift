import Foundation

public protocol WritableChannel {

    associatedtype Item


    func write(_ item: Item?)


}
