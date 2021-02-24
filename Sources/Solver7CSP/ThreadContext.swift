import Foundation
import Darwin.C
import Atomics

public class ThreadContext {

    public static let UNINITIALIZED: Int32 = 0
    public static let INITIALIZED: Int32 = 1
    public static let STARTED: Int32 = 2
    public static let ENDED: Int32 = 3


    static func destroyMe(_ ptr: UnsafeMutableRawPointer) -> Void {
        // print("destroy me called: \(ptr)")
        let ctxPtr = ptr.bindMemory(to: ThreadContext.self, capacity: 1)
        let ctx = ctxPtr.pointee
        // print("destroy me - we have : \(ctx.name)")
        if let dm = ctx._destroyMe {
            dm()
        }
    }

    static let contextKey = { () -> pthread_key_t in
        var key: pthread_key_t = 0
        pthread_key_create(&key,
                { (_ ptr: UnsafeMutableRawPointer) -> Void in
                    destroyMe(ptr)
                }
        )
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

    private let upDown = UpDown()

    private var _selfPtr: UnsafeMutablePointer<ThreadContext>? = nil

    private var _runnable: (() -> Void)? = nil

    private var _destroyMe: (() -> Void)? = nil

    private let _state = ManagedAtomic<Int32>(ThreadContext.UNINITIALIZED)

    init() {
        _id = pthread_self()
        _name = _id.debugDescription
        _state.store(ThreadContext.STARTED, ordering: .relaxed)
    }

    static func doNothing() -> Void {
    }

    public init(name: String, destroyMe: (() -> Void)? = nil, execute runnable: @escaping () -> Void) {
        _runnable = runnable
        _name = name
        _destroyMe = destroyMe
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
            pthread_setspecific(ThreadContext.contextKey, selfPtr)
            selfPtr.pointee._runnable!()
            selfPtr.pointee._state.store(ThreadContext.ENDED, ordering: .relaxed)
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

}