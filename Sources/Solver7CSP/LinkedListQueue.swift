import Foundation
import Atomics

/**
 Note: this non-blocking queue is not thread safe.  Channel with read/write locks and count management
 need to surround the usage of this class to make it thread safe.
 */
public class LinkedListQueue<T: Equatable>: QueueStore {

    private var _count = ManagedAtomic<Int>(0)

    public var count: Int {
        _count.load(ordering: .acquiring)
    }

    private let _max: Int

    public var max: Int {
        get {
            _max
        }
    }

    var head: QStoreNode<T>
    var tail: QStoreNode<T>

    public required init(max: Int) {
        _max = max
        tail = QStoreNode(nil)
        head = tail
    }

    public func put(_ item: T?) -> Int {
        enqueue(value: item)
    }

    public func putForNode(_ item: T?) -> (Int, U: StoreNode) {
        enqueueForNode(value: item)
    }

    public func get() -> T? {
        dequeue()
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
                _count.wrappingDecrement(ordering: .relaxed)
                return true
            }
            p = n!
            n = n?.next
        }
        return false
    }

    public func clear() -> Int {
        var num: Int = 0
        while _count.loadThenWrappingDecrement(ordering: .relaxed) > 0 {
            dequeue()
            num += 1
        }
        _count.store(0, ordering: .relaxed)
        return num
    }

    public var state: StoreState {
        let size = _count.load(ordering: .relaxed)
        if (size > 0) {
            if (size != _max) {
                return StoreState.NONEMPTY
            }
            return StoreState.FULL
        }
        return StoreState.EMPTY
    }

    public func isFull() -> Bool {
        _max == _count.load(ordering: .relaxed)
    }

    public func isEmpty() -> Bool {
        0 == _count.load(ordering: .relaxed)
    }


    /////

    func enqueue(value: T?) -> Int {
        let newNode = QStoreNode(value)
        tail.next = newNode
        tail = newNode
        return _count.wrappingIncrementThenLoad(ordering: .relaxed)
    }

    func enqueueForNode(value: T?) -> (Int, U: StoreNode) {
        let newNode = QStoreNode(value)
        tail.next = newNode
        tail = newNode
        return (_count.wrappingIncrementThenLoad(ordering: .relaxed), newNode)
    }

    func dequeue() -> T? {
        let h = head
        let newHead = h.next!
        h.next = h
        head = newHead
        let value = newHead.value
        newHead.value = nil
        _count.wrappingDecrement(ordering: .relaxed)
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
