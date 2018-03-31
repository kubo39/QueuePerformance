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
        var TP = atomicLoadN(addr(Q.tail), ATOMIC_ACQUIRE)
        discard cas(addr(TP), tail, next)
      else:
        value = next.value
        var HP = atomicLoadN(addr(Q.head), ATOMIC_ACQUIRE)
        if cas(addr(HP), head, next):
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
        value = next.value
        return true

when isMainModule:
  import os, times
  var
    Q = msqInitialize[int]()
    C: Channel[int]
    i: int

  Q.push(1)

  assert(Q.pop(i))
  assert(i == 1) # 1

  assert(not Q.pop(i))
  assert(i == 1)

  Q.push(2)
  Q.push(3)
  Q.push(4)
  Q.push(5)

  assert(Q.pop(i))
  assert(i == 2) # 2
  assert(Q.pop(i))
  assert(i == 3) # 3
  assert(Q.pop(i))
  assert(i == 4) # 4

  assert(Q.peek(i))
  assert(i == 5) # 5

  # Benchmark msqueue vs Nim's channel

  Q = msqInitialize[int]()
  open(C)

  var old =  epochTime()
  for ii in 0 .. 100000:
    Q.push(ii)
    discard Q.pop(i)
  echo "msq done"
  echo epochTime() - old

  old =  epochTime()
  for ii in 0 .. 100000:
    C.send(ii)
    discard C.recv()

  echo "chan done"
  echo epochTime() - old