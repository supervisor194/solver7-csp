# Solver7CSP

Communicating Sequential Processes, CSP, inspired threading data structures and control.  The fundamental concept is
that of a Channel.  The Channel is a synchronization point for multiple threads of control, writers and readers.  
It can be thought of as a rendezvous point for two or more threads wishing to communicate.  The simplest setup is
```
Writer --> Channel <-- Reader 
```

where Channel has a single item buffer whereupon a Writer.write blocks after filling the Channel to capaicty
until a Reader.read clears the Channel.  This concept can be extended to allow buffered Channels whereupon the 
Writer.write blocks when the buffered Channel remains at capacity.  

The underlying locking mechanisms should be efficient in the context of multiple Writers and Readers as well
```
Writer 1                                   Reader 1
Writer 2                                   Reader 2
Writer ...         -->  Channel  <--       Reader ...
Writer N1                                  Reader N2


Writer  {
  while true {
      let msg = buildMsg()
      channel.write(msg)
  }
}
  
Reader  {
   while true {
       let msg = channel.read()!
       doSomething(msg)
   }
}
```

When a Channel is Selectable it can be used by a Selector over multiple selectables channels and timers.

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



