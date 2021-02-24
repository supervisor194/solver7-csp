import Foundation

class CDLL<T> {

    var _size = 0

    public var size: Int {
        get {
            _size
        }
    }

    var head: CDLLNode<T>? = nil
    var tail: CDLLNode<T>? = nil

    public init() {
    }


    public func add(_ value: T) -> CDLLNode<T> {
        let last = tail
        let node = CDLLNode<T>(value, last, head)
        tail = node
        if last == nil {
            head = node
            node.next = node
        } else {
            last?.next = node
        }
        head?.prev = tail
        _size += 1
        return node
    }

    public func remove(_ node: CDLLNode<T>) {
        _size -= 1
        node.value = nil
        if _size == 0 {
            head = nil
            tail = nil
        } else {
            node.next?.prev = node.prev
            node.prev?.next = node.next
            if node === head {
                head = node.next
            } else if node === tail {
                tail = node.prev
            }
        }
    }

    public func find(finder: @escaping (_ node: CDLLNode<T>) -> CDLLNode<T>?) -> CDLLNode<T>? {
        find(beginAt: head, finder: finder)
    }

    private func startAt(beginAt: CDLLNode<T>?) -> CDLLNode<T>? {
        if let startAt = beginAt {
            return startAt
        }
        if let startAt = head {
            return startAt
        }
        return nil
    }

    public func find(beginAt: CDLLNode<T>?, finder: @escaping (_ node: CDLLNode<T>) -> CDLLNode<T>?) -> CDLLNode<T>? {
        if let startAt = startAt(beginAt: beginAt) {
            var node = startAt
            repeat {
                if let result = finder(node) {
                    return result
                }
                node = node.next!
            } while node !== startAt
        }
        return nil
    }

}


class CDLLNode<T> {
    var value: T?
    var prev: CDLLNode<T>?
    var next: CDLLNode<T>?

    init(_ value: T?, _ prev: CDLLNode<T>?, _ next: CDLLNode<T>?) {
        self.value = value
        self.prev = prev
        self.next = next
    }

    func getValue() -> T? {
        value
    }

    func getNext() -> CDLLNode<T>? {
        next
    }

}
