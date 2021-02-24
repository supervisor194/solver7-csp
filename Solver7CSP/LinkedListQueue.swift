import Foundation
import Atomics

public class LinkedListQueue<T: Equatable>: QueueStore {

    private var _cnt = ManagedAtomic<Int>(0)

    public var count: Int {
        _cnt.load(ordering: .acquiring)
    }

    private let _max: Int

    public var max: Int {
        get {
            _max
        }
    }

    var head: QStoreNode<T>
    var tail: QStoreNode<T>

    public init(max: Int) {
        _max = max
        tail = QStoreNode(nil)
        head = tail
    }

    public func put(_ item: T?) -> Int {
        enqueue(value: item)
        return _cnt.wrappingIncrementThenLoad(ordering: .relaxed)
    }

    public func putForNode(_ item: T?) -> (Int, U: StoreNode) {
        let newNode = enqueueForNode(value: item)
        return (_cnt.wrappingIncrementThenLoad(ordering: .relaxed), newNode)
    }

    public func get() -> T? {
        let value = dequeue()
        _cnt.wrappingDecrement(ordering: .relaxed)
        return value
    }

    public func get(into: inout [T?], upTo: Int) -> (Int, Int) {
        let c = count
        let size = min(c, upTo);
        var i = 0
        while i < size {
            into.append(get())
            i += 1
        }
        return (c, count)
    }

    public func getWithCount() -> (T?, Int) {
        if _cnt.load(ordering: .relaxed) > 0 {
            let value = dequeue()
            return (value, _cnt.wrappingDecrementThenLoad(ordering: .relaxed))
        } else {
            return (nil, -1)
        }
    }

    public func take() -> T? {
        get()
    }

    public func remove(_ node: QStoreNode<T>) -> Bool {
        return false
    }


    public func remove(_ item: T?) -> Bool {
        var p: QStoreNode = head
        var n: QStoreNode? = p.next
        while n != nil {
            if (item == n?.value) {
                n?.value = nil
                p.next = n?.next
                if (n?.next == nil) {
                    tail = p
                }
                _cnt.wrappingDecrement(ordering: .relaxed)
                return true
            }
            p = n!
            n = n?.next
        }
        return false
    }

    public func clear() -> Int {
        var num: Int = 0
        while _cnt.loadThenWrappingDecrement(ordering: .relaxed) > 0 {
            dequeue()
            num += 1
        }
        _cnt.store(0, ordering: .relaxed)
        return num
    }

    public var state: StoreState {
        let size = _cnt.load(ordering: .relaxed)
        if (size > 0) {
            if (size != _max) {
                return StoreState.NONEMPTY
            }
            return StoreState.FULL
        }
        return StoreState.EMPTY
    }

    public func isFull() -> Bool {
        _max == _cnt.load(ordering: .relaxed)
    }

    public func isEmpty() -> Bool {
        0 == _cnt.load(ordering: .relaxed)
    }


    /////

    func enqueue(value: T?) {
        let newNode = QStoreNode(value)
        tail.next = newNode
        tail = newNode
    }

    func enqueueForNode(value: T?) -> QStoreNode<T> {
        let newNode = QStoreNode(value)
        tail.next = newNode
        tail = newNode
        return newNode
    }

    func dequeue() -> T? {
        let h = head
        let newHead = h.next!
        h.next = h
        head = newHead
        let value = newHead.value
        newHead.value = nil
        return value
    }

}


public class QStoreNode<T>: StoreNode {
    var value: T?
    var next: QStoreNode?

    init(_ value: T?) {
        self.value = value
    }
}
