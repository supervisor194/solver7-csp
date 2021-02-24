import Foundation

open class Task: Equatable {
    private let _uuid: UUID
    public var uuid: UUID {
        get {
            _uuid
        }
    }
    private let _numTokens: Int
    public var numTokens: Int {
        get {
            _numTokens
        }
    }

    private var _handler: () -> Void

    public var handler: () -> Void {
        get {
            _handler
        }
        set {
            _handler = newValue
        }
    }

    public final func handle() -> Void {
        _handler()
    }

    public init(_ uuid: UUID, _ numTokens: Int, _ handler: (() -> Void)? = nil) {
        _uuid = uuid
        _numTokens = numTokens
        if let h = handler {
            _handler = h
        } else {
            _handler = { () -> Void in
                print("default handler, should probably supply one...")
            }
        }
    }

    public static func ==(lhs: Task, rhs: Task) -> Bool {
        if lhs === rhs {
            return true
        }
        return lhs.uuid == rhs.uuid
    }


}


