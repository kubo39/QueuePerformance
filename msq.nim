type
  MSNode[T] = object
    value: T
    next: ptr MSnode[T]

  MSQueue*[T] = object
    head, tail: ptr MSNode[T]

proc newNode[T](): ptr MSNode[T] =
  result = cast[ptr MSNode[T]](alloc(sizeof(MSNode[T])))
  result.next = nil

proc msqInitialize*[T](): ptr MSQueue[T] =
  var node = newNode[T]()

  result = cast[ptr MSQueue[T]](alloc0(sizeof(MSQueue[T])))
  result.head = node
  result.tail = node

proc push*[T](Q: ptr MSQueue, value: T) =
  var
    node = newNode[T]()
    tail, next: ptr MSNode[T]

  node.value = value

  while true:
    tail = atomicLoadN(addr(Q.tail), ATOMIC_ACQUIRE)
    next = tail.next
    if tail != atomicLoadN(addr(Q.tail), ATOMIC_ACQUIRE): continue
    if next == nil:
      if cas(addr(tail.next), next, node):
        discard cas(addr(Q.tail), tail, node)
        return
    else:
      discard cas(addr(Q.tail), tail, next)

proc pop*[T](Q: ptr MSQueue, value: var T): bool =
  var
    head, tail, next: ptr MSNode[T]

  while true:
    head = atomicLoadN(addr(Q.head), ATOMIC_ACQUIRE)
    tail = atomicLoadN(addr(Q.tail), ATOMIC_ACQUIRE)
    next = head.next

    if head != atomicLoadN(addr(Q.head), ATOMIC_ACQUIRE): continue
    if head == tail:
      if isNil(next):
        return false
      discard cas(addr(Q.tail), tail, next)
    else:
      value = next.value
      if cas(addr(Q.head), head, next):
        return true

proc peek*[T](Q: ptr MSQueue, value: var T): bool =
  var
    head, tail, next: ptr MSNode[T]

  while true:
    head = atomicLoadN(addr(Q.head), ATOMIC_ACQUIRE)
    tail = atomicLoadN(addr(Q.tail), ATOMIC_ACQUIRE)
    next = head.next

    if head != atomicLoadN(addr(Q.head), ATOMIC_ACQUIRE): continue
    if head == tail:
      if isNil(next):
        return false
      discard cas(addr(Q.tail), tail, next)
    else:
      value = next.value
      return true

proc free*(Q: ptr MSQueue) =
  dealloc(Q)

when isMainModule:
  import os
  import strformat
  import times
  
  const MESSAGES = 5_000_000
  const THREADS = 4
  
  type IntChannel = ptr MSQueue[int]
  var channels: array[0..3, IntChannel]
  
  proc seque =
    channels[0] = msqInitialize[int]()
    for i in 0 .. MESSAGES - 1:
      channels[0].push(int(i))
    for i in 0 .. MESSAGES - 1:
      var i: int
      discard channels[0].pop(i)
    channels[0].free()

  proc sender1 {.thread.} =
    for i in 0 .. MESSAGES - 1:
      channels[1].push(int(i))
  
  proc receiver1 {.thread.} =
    for i in 0 .. MESSAGES - 1:
      var i: int
      discard channels[1].pop(i)
  
  proc spsc =
    var
      spscSender: Thread[void]
      spscReceiver: Thread[void]
  
    channels[1] = msqInitialize[int]()
    createThread(spscSender, sender1)
    createThread(spscReceiver, receiver1)
    joinThread(spscSender)
    joinThread(spscReceiver)
    channels[1].free()
  
  proc sender2 {.thread.} =
    for i in 0 .. uint(MESSAGES / THREADS) - 1:
      channels[2].push(int(i))
  
  proc receiver2 {.thread.} =
    for i in 0 .. MESSAGES - 1:
      var i: int
      discard channels[2].pop(i)
  
  proc mpsc =
    var
      mpscSender: array[0 .. THREADS - 1, Thread[void]]
      mpscReceiver: Thread[void]
  
    channels[2] = msqInitialize[int]()
    for i in 0 .. THREADS - 1:
      createThread(mpscSender[i], sender2)
    createThread(mpscReceiver, receiver2)
    joinThreads(mpscSender)
    joinThread(mpscReceiver)
    channels[2].free()
  
  
  proc sender3 {.thread.} =
    for i in 0 .. uint(MESSAGES / THREADS) - 1:
      channels[3].push(int(i))
  
  proc receiver3 {.thread.} =
    for i in 0 .. uint(MESSAGES / THREADS) - 1:
      var i: int
      discard channels[3].pop(i)
  
  proc mpmc =
    var
      mpmcSender: array[0 .. THREADS - 1, Thread[void]]
      mpmcReceiver: array[0 .. THREADS - 1, Thread[void]]
    channels[3] = msqInitialize[int]()
    for i in 0 .. THREADS - 1:
      createThread(mpmcSender[i], sender3)
    for i in 0 .. THREADS - 1:
      createThread(mpmcReceiver[i], receiver3)
    joinThreads(mpmcSender)
    joinThreads(mpmcReceiver)
    channels[3].free()
  
  proc run(name: string, f: proc()) =
    let time = epochTime()
    f()
    let elapsed = epochTime() - time
    echo &"""{name:<25} {"Nim channel":<15} {elapsed:7.3} sec"""
  
  when isMainModule:
    run("unbounded_seq", seque)
    run("unbounded_spsc", spsc)
    run("unbounded_mpsc", mpsc)
    run("unbounded_mpmc", mpmc)  