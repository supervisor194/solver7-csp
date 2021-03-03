import Foundation


public protocol ChannelCreator {
    func create<T: Equatable>(t: T.Type) -> AnyChannel<T>
}


public enum ChannelFactory {
}

public extension ChannelFactory {

    enum Default: ChannelCreator {
        case LLQ(max: Int, writeLock: Lock = NonFairLock(10), readLock: Lock = NonFairLock(10))
        case SVS(writeLock: Lock = NonFairLock(10), readLock: Lock = NonFairLock(10))
        case SLLQ(id: String, max: Int)

        public func create<T: Equatable>(t: T.Type) -> AnyChannel<T> {
            switch self {
            case let .LLQ(max, writeLock, readLock):
                return AnyChannel(NonSelectableChannel(store: AnyStore(LinkedListQueue<T>(max: max)),
                        writeLock: writeLock, readLock: readLock))
            case let .SVS(writeLock, readLock):
                return AnyChannel(NonSelectableChannel(store: AnyStore(SingleValueStore<T>()),
                        writeLock: writeLock, readLock: readLock))
            case let .SLLQ(id, max):
                return AnyChannel(SelectableChannel(id: id, store: AnyStore(LinkedListQueue<T>(max: max))))
            }
        }
    }

}