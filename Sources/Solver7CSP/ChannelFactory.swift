import Foundation


public protocol ChannelCreator {
    func create<T: Equatable>(t: T.Type) -> AnyChannel<T>
}


public enum ChannelFactory {
}

public extension ChannelFactory {

    enum Default: ChannelCreator {
        case LLQ(max: Int, maxWriters: Int = 10, maxReaders: Int = 10, lockType: LockType = LockType.NON_FAIR_LOCK)
        case SVS
        case SLLQ(id: String, max: Int, maxWriters: Int = 10, maxReaders: Int = 10, lockType: LockType = LockType.NON_FAIR_LOCK)

        public func create<T: Equatable>(t: T.Type) -> AnyChannel<T> {
            switch self {
            case let .LLQ(max, maxWriters, maxReaders, lockType):
                return AnyChannel(NonSelectableChannel(store: AnyStore(LinkedListQueue<T>(max: max)),
                        maxWriters: maxWriters, maxReaders: maxReaders, lockType: lockType))
            case .SVS:
                return AnyChannel(NonSelectableChannel(store: AnyStore(SingleValueStore<T>())))
            case let .SLLQ(id, max, maxWriters, maxReaders, lockType):
                return AnyChannel(SelectableChannel(id: id, store: AnyStore(LinkedListQueue<T>(max: max)),
                        maxWriters: maxWriters, maxReaders: maxReaders, lockType: lockType))
            }
        }
    }

}