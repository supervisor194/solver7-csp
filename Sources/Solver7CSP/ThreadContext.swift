import Foundation
import Darwin.C
import Atomics

public class ThreadContext {

    public static let UNINITIALIZED: Int32 = 0
    public static let INITIALIZED: Int32 = 1
    public static let STARTED: Int32 = 2
    public static let PREDESTROY: Int32 = 3
    public static let ENDED: Int32 = 4


    /*
    static func destroyMe(_ ptr: UnsafeMutableRawPointer) -> Void {
        // print("destroy me called: \(ptr)")
        let ctxPtr = ptr.bindMemory(to: ThreadContext.self, capacity: 1)
        let ctx = ctxPtr.pointee
        print("destroy me - we have : \(ctx.name)")
        if let dm = ctx._destroyMe {
            dm()
        }
        ctx._state.store(ThreadContext.ENDED, ordering: .relaxed)
    }
     */

    static let contextKey = { () -> pthread_key_t in
        var key: pthread_key_t = 0
        /*
        pthread_key_create(&key,
                { (_ ptr: UnsafeMutableRawPointer) -> Void in
                    destroyMe(ptr)
                }
        )
         */
        pthread_key_create(&key, nil)
        return key
    }()


    public static func currentContext() -> ThreadContext {
        if let ptr: UnsafeMutableRawPointer = pthread_getspecific(ThreadContext.contextKey) {
            let ctx = ptr.assumingMemoryBound(to: ThreadContext.self).pointee
            return ctx
        } else {
            let ctx = ThreadContext()
            let ptr = UnsafeMutablePointer<ThreadContext>.allocate(capacity: 1)
            ptr.initialize(to: ctx)
            pthread_setspecific(ThreadContext.contextKey, ptr)
            return ctx
        }
    }


    ///////////  per instance values

    private var _id: pthread_t? = nil

    private var _name: String

    var name: String {
        get {
            _name
        }
        set {
            _name = newValue
        }
    }

    public var id: pthread_t? {
        get {
            _id
        }
    }

    private let upDown = UpDown()

    private var _selfPtr: UnsafeMutablePointer<ThreadContext>? = nil

    private var _runnable: (() -> Void)? = nil

    private var _destroyMe: (() -> Void)? = nil

    private let _state = ManagedAtomic<Int32>(ThreadContext.UNINITIALIZED)

    private let completionLock = NonFairLock(10000)
    private let joinCondition: Condition

    public var state:Int32 {
        get {
            _state.load(ordering: .relaxed)
        }
    }

    init() {
        _id = pthread_self()
        _name = _id.debugDescription
        _state.store(ThreadContext.STARTED, ordering: .relaxed)
        joinCondition = completionLock.createCondition()
    }

    public init(name: String, destroyMe: (() -> Void)? = nil, execute runnable: @escaping () -> Void) {
        _runnable = runnable
        _name = name
        _destroyMe = destroyMe
        joinCondition = completionLock.createCondition()
        _selfPtr = UnsafeMutablePointer<ThreadContext>.allocate(capacity: 1)
        _selfPtr?.initialize(to: self)
        _state.store(ThreadContext.INITIALIZED, ordering: .relaxed)
    }

    public func start() -> Int32 {
        if !_state.compareExchange(expected: ThreadContext.INITIALIZED, desired: ThreadContext.STARTED, ordering: .relaxed).exchanged {
            print("already started or done")
            return -1
        }

        func tfunc(t_data: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
            let selfPtr = t_data.bindMemory(to: ThreadContext.self, capacity: 1)
            let tc = selfPtr.pointee
            pthread_setspecific(ThreadContext.contextKey, selfPtr)
            tc._runnable!()
            if let dm = tc._destroyMe {
                dm()
            }
            tc._state.store(ThreadContext.ENDED, ordering: .relaxed)
            tc.completionLock.lock() // the key value has been destroyed, so this won't work, it will create a new key
            tc.joinCondition.doNotify()
            tc.completionLock.unlock()
            return nil
        }

        return pthread_create(&_id, nil, tfunc, _selfPtr)
    }

    public func down() {
        upDown.down()
    }

    public func down(_ until: inout timespec) {
        upDown.down(&until)
    }

    public func up() {
        upDown.up()
    }

    /**

     - Parameter timeoutAt:
     - Returns: 0 joined, 1 timed out
     */
    public func join(_ timeoutAt: inout timespec) -> Int32 {
        completionLock.lock()
        defer {
            completionLock.unlock()
        }
        while _state.load(ordering: .relaxed) != ThreadContext.ENDED && !TimeoutState.expired(timeoutAt) {
            joinCondition.doWait(&timeoutAt)
        }
        if _state.load(ordering: .relaxed) == ThreadContext.ENDED {
            return 0
        }
        return 1
    }

}