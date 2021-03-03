import Foundation


public protocol ChannelCreator {
    func create<T: Equatable>(t: T.Type) -> AnyChannel<T>
}


public enum ChannelFactory {
}

public extension ChannelFactory {

    enum Default: ChannelCreator {
        case LLQ(max: Int)
        case SVS
        case SLLQ(id: String, max: Int)

        public func create<T: Equatable>(t: T.Type) -> AnyChannel<T> {
            switch self {
            case let .LLQ(max):
                return AnyChannel(NonSelectableChannel(store: AnyStore(LinkedListQueue<T>(max: max))))
            case .SVS:
                return AnyChannel(NonSelectableChannel(store: AnyStore(SingleValueStore<T>())))
            case let .SLLQ(id, max):
                return AnyChannel(SelectableChannel(id: id, store: AnyStore(LinkedListQueue<T>(max: max))))
            }
        }
    }

}