import Foundation

public class TimeoutState {
    public static let DISABLED: Int = 0
    public static let ENABLED: Int = 1
    public static let CONSUMED: Int = 2

    public static func computeTimeoutTimespec(sec: Int, nanos: Int) -> timespec {
        var now = timeval()
        gettimeofday(&now, nil)
        return computeTimeoutTimespec(sec: sec, nanos: nanos, now: now)
    }

    public static func computeTimeoutTimespec(sec: Int, nanos: Int, now: timeval) -> timespec {
        var ts = timespec()
        ts.tv_sec = now.tv_sec + sec
        let nsec = nanos + Int(now.tv_usec) * 1000
        ts.tv_nsec = nsec
        if nsec > 1000000000 {
            ts.tv_sec += 1
            ts.tv_nsec -= 1000000000
        }
        return ts
    }

    public static func expired(_ timeoutAt: timespec) -> Bool {
        var now = timeval()
        gettimeofday(&now, nil)
        return earlier(time: timeoutAt, earlierThan: now)
    }

    public static func earlier(time t1: timespec, earlierThan t2: timeval) -> Bool {
        if t1.tv_sec > t2.tv_sec {
            return false
        }
        if t1.tv_sec < t2.tv_sec {
            return true
        }
        return t1.tv_nsec < t2.tv_usec * 1000
    }

    public static func differenceInUSec(_ t1: timeval, _ t2: timeval) -> Int {
        let t1USec = t1.tv_sec * 1000000 + Int(t1.tv_usec)
        let t2USec = t2.tv_sec * 1000000 + Int(t2.tv_usec)
        return t1USec - t2USec
    }
}

public class Timeout<T>: Selectable {

    let id: String
    var handler: (() -> Void)? = nil

    var state = TimeoutState.DISABLED

    public init(id: String) {
        self.id = id
    }

    public func getId() -> String {
        return id
    }

    public func setHandler(_ handler: (() -> Void)?) -> Void {
        self.handler = handler
    }

    public func handle() -> Void {
        handler!()
    }

    public func read() -> T? {
        state = TimeoutState.CONSUMED
        let e = event
        event = nil
        return e
    }

    var timeoutTime: timespec? = nil

    public func setTimeout(_ at: timespec) {
        timeoutTime = at
        state = TimeoutState.ENABLED
    }

    var event: T? = nil

    public func setTimeout(_ at: timespec, _ event: T) {
        self.event = event
        setTimeout(at)
    }

    var _enableable = false

    public func isEnableable() -> Bool {
        _enableable
    }

    public func setEnableable(_ b: Bool) {
        _enableable = b
    }

    var _selector: Selector? = nil

    public func setSelector(_ selector: Selector?) -> Void {
        _selector = selector
    }

    public func hasData() -> Bool {
        if !_enableable {
            return false
        }
        if (state == TimeoutState.CONSUMED) || (state == TimeoutState.DISABLED) {
            return false
        }
        _selector!.setTimeoutAt(timeoutTime!)
        return TimeoutState.expired(timeoutTime!)
    }

    let m = Mutex()

    public func enable(_ selector: Selector) -> Bool {
        m.lock()
        defer  {
            m.unlock()
        }
        _enableable = true
        _selector = selector
        return hasData()
    }


    public func disable() -> Bool {
        m.lock()
        defer {
            m.unlock()
        }
        let h = _enableable && TimeoutState.expired(timeoutTime!) && state != TimeoutState.DISABLED
        _selector!.schedule()
        _enableable = false
        state = TimeoutState.DISABLED
        return h
    }


}
