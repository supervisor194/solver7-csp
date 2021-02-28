import Foundation

public class SelectableChannel<T>: NonSelectableChannel<T>, Selectable {

    private let id: String
    private var handler: (() -> Void)? = nil
    private var _enableable: Bool = false
    private var _selector: Selector? = nil

    public init(id: String, store: AnyStore<T>, maxWriters: Int = 10, maxReaders: Int = 10, lockType: LockType = LockType.NON_FAIR_LOCK) {
        self.id = id
        super.init(store: store, maxWriters: maxWriters, maxReaders: maxReaders, lockType: lockType)
    }

    public func getId() -> String {
        id
    }

    public func isEnableable() -> Bool {
        _enableable
    }

    public func setEnableable(_ b: Bool) {
        _enableable = b
    }

    public func hasData() -> Bool {
        _enableable && s.count > 0
    }

    public func setHandler(_ handler: @escaping () -> Void) -> Void {
        self.handler = handler
    }

    public func handle() -> Void {
        handler!()
    }

    public func setSelector(_ selector: Selector?) {
        _selector = selector
    }

    public func enable(_ selector: Selector) -> Bool {
        writeLock.lock()
        defer  {
            writeLock.unlock()
        }
        _enableable = true
        _selector = selector
        if s.isEmpty() {
            return false
        } else {
            selector.schedule()
            return true
        }
    }

    public func disable() -> Bool {
        writeLock.lock()
        defer {
            writeLock.unlock()
        }
        _enableable = false
        _selector = nil
        return !s.isEmpty()
    }

    public override func write(_ item: T?) {
        writeLock.lock()
        defer  {
            writeLock.unlock()
        }
        let c = s.put(item)
        if let selector = _selector {
            selector.schedule()
        }
        if c == 1 {
            do {
                readLock.lock()
                defer {
                    readLock.unlock()
                }
                readLock.doNotify()
            }
        }
        while s.count == capacity {
            ThreadContext.currentContext().down()
        }
    }


}
