import Foundation
import Atomics

public class FairSelector: Selector {

    public enum FairSelectorError: Error {
        case duplicateId(msg: String)
    }

    let state = ManagedAtomic<Int>(0)
    let stateLock = NonFairLock(10)
    let condition : Condition

    let selectables = CircularDoubleLinkedList<Selectable>()
    var idealNext: CDLLNode<Selectable>? = nil

    private static let INACTIVE = 0
    private static let ENABLING = 1
    private static let WAITING = 2
    private static let READY = 3

    private var hasTimeout = false
    private var timeoutAt: timespec? = nil

    private var mutex = Mutex()

    public init(_ selectables: [Selectable]) throws {
        state.store(FairSelector.INACTIVE, ordering: .relaxed)
        hasTimeout = false
        condition = stateLock.createCondition()

        for s in selectables {
            try addSelectable(s)
        }
    }

    public func addSelectable(_ selectable: Selectable) throws {
        mutex.lock()
        defer {
            mutex.unlock()
        }
        if let node = selectables.find(finder: { (n) -> CDLLNode<Selectable>? in
            if n.value!.getId() == selectable.getId() {
                return n
            }
            return nil
        }) {
            throw FairSelectorError.duplicateId(msg: "oops, duplicate id detected, each must be unique")
        }
        selectable.setSelector(self)
        selectable.setEnableable(true)
        let node = selectables.add(selectable)
        if idealNext == nil {
            idealNext = node
        }
    }

    public func removeSelectable(_ id: String) -> Bool {
        mutex.lock()
        defer {
            mutex.unlock()
        }
        if let node = selectables.find(finder: { (n) -> CDLLNode<Selectable>? in
            if n.value!.getId() == id {
                return n
            }
            return nil
        }) {
            if idealNext === node {
                if selectables.size == 1 {
                    idealNext = nil
                } else {
                    idealNext = idealNext?.next
                }
            }
            selectables.remove(node)
            return true
        }
        return false
    }

    public func select() -> Selectable {
        var selected: Selectable? = nil
        repeat {
            state.store(FairSelector.ENABLING, ordering: .relaxed)
            selected = checkEnabled()
            do {
                stateLock.lock()
                defer {
                    stateLock.unlock()
                }
                if state.compareExchange(expected: FairSelector.ENABLING, desired: FairSelector.WAITING, ordering: .relaxed).exchanged {
                    if hasTimeout && !TimeoutState.expired(timeoutAt!) {
                        condition.doWait(&timeoutAt!)
                    } else {
                        condition.doWait()
                    }
                }
            }
            state.store(FairSelector.INACTIVE, ordering: .relaxed)
        } while selected == nil
        hasTimeout = false
        return selected!
    }

    func hasData(node: CDLLNode<Selectable>) -> CDLLNode<Selectable>? {
        if let selectable = node.value {
            if selectable.hasData() {
                return node
            }
        }
        return nil
    }

    private func checkEnabled() -> Selectable? {
        if let node = selectables.find(beginAt: idealNext, finder: hasData) {
            if node === idealNext {
                idealNext = idealNext?.next
            }
            state.store(FairSelector.READY, ordering: .relaxed)
            return node.value
        }
        return nil
    }


    public func schedule() -> Void {
        if state.exchange(FairSelector.READY, ordering: .relaxed) == FairSelector.WAITING {
            stateLock.lock()
            defer {
                stateLock.unlock()
            }
            condition.doNotify()
        }
    }

    public func setTimeoutAt(_ at: timespec) {
        if hasTimeout {
            if earlier(at, timeoutAt!) {
                timeoutAt = at
            }
        } else {
            hasTimeout = true
            timeoutAt = at
        }
    }

    func earlier(_ t1: timespec, _ t2: timespec) -> Bool {
        if t1.tv_sec < t2.tv_sec {
            return true
        }
        if (t1.tv_sec > t2.tv_sec) {
            return false
        }
        return t1.tv_nsec < t2.tv_nsec
    }
}
