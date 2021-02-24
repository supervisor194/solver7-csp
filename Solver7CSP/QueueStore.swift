import Foundation


public protocol QueueStore: Store {

    func take() -> Item?

}
