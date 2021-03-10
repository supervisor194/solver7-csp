import Foundation


public protocol ChannelCreator {
    func create<T: Equatable>(t: T.Type) -> AnyChannel<T>
}

public protocol SelectableChannelCreator {
    func create<T: Equatable>(t: T.Type) -> SelectableChannel<T>
}


public enum ChannelFactory {
}

public extension ChannelFactory {

    enum AsAny: ChannelCreator {
        case LLQ(max: Int, writeLock: Lock = NonFairLock(10), readLock: Lock = NonFairLock(10))
        case SVS(writeLock: Lock = NonFairLock(10), readLock: Lock = NonFairLock(10))
        case SLLQ(id: String, max: Int, writeLock: Lock = NonFairLock(10), readLock: Lock = NonFairLock(10))
        case SSVS(id: String, writeLock: Lock = NonFairLock(10), readLock: Lock = NonFairLock(10))

        public func create<T: Equatable>(t: T.Type) -> AnyChannel<T> {
            switch self {
            case let .LLQ(max, writeLock, readLock):
                return AnyChannel(NonSelectableChannel(store: AnyStore(LinkedListQueue<T>(max: max)),
                        writeLock: writeLock, readLock: readLock))
            case let .SVS(writeLock, readLock):
                return AnyChannel(NonSelectableChannel(store: AnyStore(SingleValueStore<T>()),
                        writeLock: writeLock, readLock: readLock))
            case let .SLLQ(id, max, writeLock, readLock):
                return AnyChannel(SelectableChannel(id: id, store: AnyStore(LinkedListQueue<T>(max: max)),
                        writeLock: writeLock, readLock: readLock))
            case let .SSVS(id, writeLock, readLock):
                return AnyChannel(SelectableChannel(id: id, store: AnyStore(SingleValueStore<T>()),
                        writeLock: writeLock, readLock: readLock))
            }
        }
    }

    enum AsSelectable: SelectableChannelCreator {
        case SLLQ(id: String, max: Int, writeLock: Lock = NonFairLock(10), readLock: Lock = NonFairLock(10))
        case SSVS(id: String, writeLock: Lock = NonFairLock(10), readLock: Lock = NonFairLock(10))

        public func create<T: Equatable>(t: T.Type) -> SelectableChannel<T> {
            switch self {
            case let .SLLQ(id, max, writeLock, readLock):
                return SelectableChannel(id: id, store: AnyStore(LinkedListQueue<T>(max: max)),
                        writeLock: writeLock, readLock: readLock)
            case let .SSVS(id, writeLock, readLock):
                return SelectableChannel(id: id, store: AnyStore(SingleValueStore<T>()),
                        writeLock: writeLock, readLock: readLock)
            }
        }
    }

}

public enum StoreFactory {
}

public protocol StoreCreator {
    func create<T: Equatable>(t: T.Type) -> AnyStore<T>
}

public extension StoreFactory {
    enum AsAny: StoreCreator {
        case LLQ(max: Int)
        case SVS

        public func create<T:Equatable>(t: T.Type) -> AnyStore<T> {
            switch self {
            case let .LLQ(max):
                return AnyStore(LinkedListQueue<T>(max: max))
            case .SVS:
                return AnyStore(SingleValueStore<T>())
            }
        }
    }
}

