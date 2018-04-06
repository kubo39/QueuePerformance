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
  import threadpool
  import times
  
  const MESSAGES = 5_000_000
  const THREADS = 4
  
  type IntMsQueue = ptr MSQueue[int]
  var channels: array[0..3, IntMsQueue]
  
  proc seque =
    channels[0] = msqInitialize[int]()
    for i in 0 .. MESSAGES - 1:
      channels[0].push(int(i))
    for i in 0 .. MESSAGES - 1:
      var ii: int
      discard channels[0].pop(ii)
    sync()
    channels[0].free()
  
  proc sender1 {.thread.} =
    for i in 0 .. MESSAGES - 1:
      channels[1].push(int(i))
  
  proc receiver1 {.thread.} =
    for i in 0 .. MESSAGES - 1:
      var ii: int
      discard channels[1].pop(ii)
  
  proc spsc =
    channels[1] = msqInitialize[int]()
    spawn sender1()
    spawn receiver1()
    sync()
    channels[1].free()
  
  proc sender2 {.thread.} =
    for i in 0 .. uint(MESSAGES / THREADS) - 1:
      channels[2].push(int(i))
  
  proc receiver2 {.thread.} =
    for i in 0 .. MESSAGES - 1:
      var ii: int
      discard channels[2].pop(ii)
  
  proc mpsc =
    channels[2] = msqInitialize[int]()
    for _ in 0 .. THREADS - 1:
      spawn sender2()
    spawn receiver2()
    sync()
    channels[2].free()
  
  proc sender3 {.thread.} =
    for i in 0 .. uint(MESSAGES / THREADS) - 1:
      channels[3].push(int(i))
  
  proc receiver3 {.thread.} =
    for i in 0 .. uint(MESSAGES / THREADS) - 1:
      var ii: int
      discard channels[3].pop(ii)
  
  proc mpmc =
    channels[3] = msqInitialize[int]()
    for _ in 0 .. THREADS - 1:
      spawn sender3()
    for _ in 0 .. THREADS - 1:
      spawn receiver3()
    sync()
    channels[3].free()
  
  proc run(name: string, f: proc()) =
    let time = epochTime()
    f()
    let elapsed = epochTime() - time
    echo &"""{name:<25} {"msq channel":<15} {elapsed:7.3} sec"""
  
  when isMainModule:
    run("unbounded_seq", seque)
    run("unbounded_spsc", spsc)
    run("unbounded_mpsc", mpsc)
    run("unbounded_mpmc", mpmc)