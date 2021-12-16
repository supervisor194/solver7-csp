import Foundation

public class SelectableChannel<T>: NonSelectableChannel<T>, Selectable {

    private var handler: (() -> Void)? = nil
    private var _enableable: Bool = false
    private var _selector: Selector? = nil

    public init(id: String, store: AnyStore<T>, writeLock: Lock = NonFairLock(10), readLock: Lock = NonFairLock(10)) {
        super.init(id: id, store: store, writeLock: writeLock, readLock: readLock)
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

    public override func write(_ item: T?) throws {
        writeLock.lock()
        defer  {
            writeLock.unlock()
        }
        let c = try s.put(item)
        if let selector = _selector {
            selector.schedule()
        }
        if c == 1 {
            do {
                readLock.lock()
                defer {
                    readLock.unlock()
                }
                notEmpty.doNotify()
            }
        }
        while s.isFull() {
            ThreadContext.currentContext().down()
        }
    }


}
