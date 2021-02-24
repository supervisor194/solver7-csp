import Foundation
import Atomics

class Mutex {

    private var mutex: pthread_mutex_t = {
        var mutex = pthread_mutex_t()
        pthread_mutex_init(&mutex, nil)
        return mutex
    }()

    public func lock() {
        pthread_mutex_lock(&mutex)
    }

    public func unlock() {
        pthread_mutex_unlock(&mutex)
    }
}


final class UpDown {

    private var mutex: pthread_mutex_t = {
        var mutex = pthread_mutex_t()
        pthread_mutex_init(&mutex, nil)
        return mutex
    }()

    private var condition: pthread_cond_t = {
        var condition = pthread_cond_t()
        pthread_cond_init(&condition, nil)
        return condition
    }()

    var numAwaiting: Int = 0
    var sv = ManagedAtomic<Int>(0)

    public init() {
    }

    public func down() -> Void {
        var v: Int
        repeat {
            v = sv.load(ordering: .acquiring)
        } while !sv.compareExchange(expected: v, desired: v - 1, ordering: .relaxed).exchanged
        if v == 0 {
            pthread_mutex_lock(&mutex)
            numAwaiting += 1
            while sv.load(ordering: .relaxed) < 0 {
                pthread_cond_wait(&condition, &mutex)
            }
            numAwaiting -= 1
            sv.store(0, ordering: .relaxed)
            pthread_mutex_unlock(&mutex)
        }
    }

    public func down(_ until: inout timespec) -> Void {
        var v: Int
        repeat {
            v = sv.load(ordering: .relaxed)
        } while !sv.compareExchange(expected: v, desired: v - 1, ordering: .relaxed).exchanged
        if v == 0 {
            pthread_mutex_lock(&mutex)
            numAwaiting += 1
            while sv.load(ordering: .relaxed) < 0 {
                let status = pthread_cond_timedwait(&condition, &mutex, &until)
                if status == ETIMEDOUT {
                    break
                }
            }
            numAwaiting -= 1
            sv.store(0, ordering: .relaxed)
            pthread_mutex_unlock(&mutex)
        }
    }

    public func up() -> Void {
        if sv.exchange(1, ordering: .acquiring) >= 0 {
            return
        }
        pthread_mutex_lock(&mutex)
        let numWaiting = numAwaiting
        if numWaiting != 0 {
            pthread_cond_signal(&condition)
        }
        pthread_mutex_unlock(&mutex)

    }


}