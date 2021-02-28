import Foundation
import XCTest

@testable import Solver7CSP


extension ChannelFactory {

    enum Mine: ChannelCreator {
        case NSLLQ100
        case NSRWLLQ100(Int, Int)

        public func create<T: Equatable>(t: T.Type) -> AnyChannel<T> {
            switch self {
            case .NSLLQ100:
                return AnyChannel(NonSelectableChannel(store: AnyStore(LinkedListQueue<T>(max: 100))))
            case let .NSRWLLQ100(maxWriters, maxReaders):
                return AnyChannel(NonSelectableChannel(store: AnyStore(LinkedListQueue<T>(max: 100)),
                        maxWriters: maxWriters, maxReaders: maxReaders))
            }
            fatalError("hmmm, can't create")
        }
    }
}


class FactoryTest: XCTestCase {

    public func testOne() throws {

        let x = ChannelFactory.Default.LLQ(max: 10).create(t: String.self)
        let sx = ChannelFactory.Default.SLLQ(id: "MySelectableChannel", max: 10).create(t: String.self)
        let y = ChannelFactory.Default.SVS.create(t: String.self)

        let zz = ChannelFactory.Mine.NSLLQ100.create(t: Int.self)
        let z2 = ChannelFactory.Mine.NSRWLLQ100(10, 1).create(t: Int.self)

        print("done")
    }
}
