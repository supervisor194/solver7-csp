# Solver7CSP

CSP inspired data structures and concurrency control for the Swift programming language.

Communicating Sequential Processes, [Wikipedia-CSP][1], patterns can be found in languages like Go, Erlang, Haskell and 
Clojure, but are not natively present in the Swift programming language.  Swift uses Grand Central Dispatch, [Apple GCD][2], for 
solving concurrency problems. However, if one would like a different, or perhaps better separation of specialized producers
and consumers, CSP may be a way to go.  This shifts the focus towards the composition of independently executing
processes (writers/readers or producers/consumers) that coordinate via messages transferred between channels. Some
examples where CSP may be a better abstraction are stream processing and time series analysis.  One often combines
multiple streams to perform an operation like perhaps addition:
```
    let x = stream1.read()
    let y = stream2.read()
    if x.key == y.key {
       z = x + y
       output.write(z)
    }
```

In CSP, the fundamental concept is a Channel. The Channel is a synchronization point for multiple threads of control,
including both writers and readers. The Channel is a rendezvous point for two or more threads wishing to communicate. 
The simplest set up is:
```
Writer --> Channel <-- Reader 
```

where Channel has a single item buffer where a Writer.write blocks after filling the Channel to capacity
until a Reader.read clears the Channel.  This concept can be extended to allow buffered Channels whereupon the 
Writer.write blocks when the buffered Channel remains at capacity.  

The underlying locking mechanisms should be efficient in the context of multiple Writers and Readers as well
```
Writer 1                                   Reader 1
Writer 2                                   Reader 2
Writer ...         -->  Channel  <--       Reader ...
Writer N1                                  Reader N2


Writer X {
  while true {
      let msg = buildMsg()
      channel.write(msg)
  }
}
  
Reader Y {
   while true {
       let msg = channel.read()!
       doSomething(msg)
   }
}
```

When a Channel is Selectable it can be used by a Selector over multiple selectables, channels and timers.

```
     SelectableChannel 1
     SelectableChannel ...      <-- Selector  
     SelectableChannel N1
     Timer 1 ... Timer N2
     
     
     while true {
        let s = selector.select()
        s.handle()
     }
```

This implementation provides two Channels and a Timeout along with a FairSelector that support multiple
writers and readers. 
```
public class NonSelectableChannel<T>: Channel
public class SelectableChannel<T>: NonSelectableChannel<T>, Selectable
public class Timeout<T>: Selectable

public protocol Selector 
public class FairSelector: Selector
```
The Channel instances may be created as per the examples or with a ChannelFactory.  Extend
the ChannelFactory as necessary to support convenient initialization.

The hopefully efficient locking mechanisms that back the implementations are useful by themselves.
They utilize the Swift Atomics package to allow wait free locks when conditions / environment permit.
```
public protocol Lock
open class ReentrantLock: Lock 
public final class FairLock: ReentrantLock 
public final class NonFairLock: ReentrantLock

let lock = NonFairLock(10) 
let sumReady = lock.createCondition()
var sum = 0 

// Thread A 
do {
 lock.lock 
 defer {
  lock.unlock()
 }
 sumReady.doWait()
 assertEquals(77, sum) 
}

// Thread B
do {
  lock.lock()
  defer {
    lock.unlock()
  }
  sum += 77
  sumReady.doNotify()
}
```
These locks are built on top of lower level, OS level, Mutexes and Conditions in addition to the Swift Atomics.
```
class Mutex {
 private var mutex: pthread_mutex_t
}

class UpDown {  
  private var mutex: pthread_mutex_t
  private var condition: pthread_cond_t
}  
```
Similarly, there are Semaphores and Latches that are built upon the underlying Channels,
Lock, Mutexes and UpDown.
```
public class Semaphore
public class CountdownLatch 
```


[1]: <https://en.wikipedia.org/wiki/Communicating_sequential_processes> "Wikipedia CSP"
[2]: <https://apple.github.io/swift-corelibs-libdispatch/> "Apple GCD"