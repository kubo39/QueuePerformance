# msqueue
# Copyright 2vg
# Michael-Scott queue implemented in Nim

type
  NodeT[T] = object
    value: T
    next: ptr NodeT[T]

  MsQueue*[T] = object
    head: ptr NodeT[T]
    tail: ptr NodeT[T]

proc newNode[T](): ref NodeT[T] =
  result = NodeT[T].new()#create(NodeT[T])
  result.next = nil

proc newMsQueue*[T](): ptr MsQueue[T] =
  result = create(MsQueue[T])
  result.head = nil
  result.tail = nil

proc msqInitialize*[T](): ptr MsQueue[T] =
  var
    Q = newMsQueue[T]()
    node = newNode[T]()

  node.next = nil

  Q.head = cast[ptr NodeT[T]](node)
  Q.tail = cast[ptr NodeT[T]](node)

  return Q

proc initialize*[T](Q: ptr MsQueue[T]) =
  var node = newNode[T]()

  node.next = nil

  atomicStoreN(addr(Q.head), cast[ptr NodeT[T]](node), ATOMIC_RELAXED)
  atomicStoreN(addr(Q.tail), cast[ptr NodeT[T]](node), ATOMIC_RELAXED)

proc push*[T](Q: ptr MsQueue[T], value: T) =
  var
    node = newNode[T]()
    next, tail: ptr NodeT[T]

  node.value = value
  node.next = nil

  while true:
    tail = atomicLoadN(addr(Q.tail), ATOMIC_ACQUIRE)
    next = tail.next
    if tail == atomicLoadN(addr(Q.tail), ATOMIC_ACQUIRE):
      if next == nil:
        if cas(addr(tail.next), nil, cast[ptr NodeT[T]](node)):
          break
      else:
        discard cas(addr(Q.tail), tail, next)
  discard cas(addr(Q.tail), tail, cast[ptr NodeT[T]](node))

proc pop*[T](Q: ptr MsQueue[T], value: var T): bool =
  var
    head, tail, next: ptr NodeT[T]

  while true:
    head = atomicLoadN(addr(Q.head), ATOMIC_ACQUIRE)
    tail = atomicLoadN(addr(Q.tail), ATOMIC_ACQUIRE)
    next = head.next

    if head == atomicLoadN(addr(Q.head), ATOMIC_ACQUIRE):
      if head == tail:
        if next == nil:
          return false
        discard cas(addr(Q.tail), tail, next)
      else:
        if next == nil:
          return false
        value = next.value
        var HP = atomicLoadN(addr(Q.head), ATOMIC_ACQUIRE)
        if cas(addr(Q.head), head, next):
          break
  return true

proc peek*[T](Q: ptr MsQueue[T], value: var T): bool =
  var
    head, tail, next: ptr NodeT[T]

  while true:
    head = atomicLoadN(addr(Q.head), ATOMIC_ACQUIRE)
    tail = atomicLoadN(addr(Q.tail), ATOMIC_ACQUIRE)
    next = head.next

    if head == atomicLoadN(addr(Q.head), ATOMIC_ACQUIRE):
      if head == tail:
        if next == nil:
          return false
        var TP = atomicLoadN(addr(Q.tail), ATOMIC_ACQUIRE)
        discard cas(addr(TP), tail, next)
      else:
        if next == nil:
          return false
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
  
  type IntMsQueue = ptr MsQueue[int]
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