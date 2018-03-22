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

proc newNode[T](): ptr NodeT[T] =
  result = createShared(NodeT[T])
  result.next = nil

proc newMsQueue*[T](): ptr MsQueue[T] =
  result = createShared(MsQueue[T])
  result.head = nil
  result.tail = nil

proc msqInitialize*[T](): ptr MsQueue[T] =
  var
    Q = newMsQueue[T]()
    node = newNode[T]()

  node.next = nil

  Q.head = node
  Q.tail = node

  return Q

proc initialize*[T](Q: ptr MsQueue[T]) =
  var node = newNode[T]()

  node.next = nil

  atomicStoreN(addr(Q.head), node, ATOMIC_RELAXED)
  atomicStoreN(addr(Q.tail), node, ATOMIC_RELAXED)

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
        if cas(addr(tail.next), next, node):
          break
      
      else:
        discard cas(addr(Q.tail), tail, next)

  discard cas(addr(Q.tail), tail, node)

proc pop*[T](Q: ptr MsQueue[T], value: var T): bool =
  var
    head, tail, next: ptr NodeT[T]

  while true:
    head = atomicLoadN(addr(Q.head), ATOMIC_ACQUIRE)
    tail = atomicLoadN(addr(Q.tail), ATOMIC_ACQUIRE)
    next = head.next

    if head == atomicLoadN(addr(Q.head), ATOMIC_ACQUIRE):
      if head.next == tail.next:
        if next == nil:
          return false
        discard cas(addr(Q.tail), tail, next)
      else:
        value = next.value
        if cas(addr(Q.head.next), next, next.next):
          break

  if tail == next:
    discard cas(addr(Q.tail), tail, head)

  freeShared(next)

  return true

proc peek*[T](Q: ptr MsQueue[T], value: var T): bool =
  var
    head, tail, next: ptr NodeT[T]

  while true:
    head = atomicLoadN(addr(Q.head), ATOMIC_ACQUIRE)
    tail = atomicLoadN(addr(Q.tail), ATOMIC_ACQUIRE)
    next = head.next

    if head == atomicLoadN(addr(Q.head), ATOMIC_ACQUIRE):
      if head.next == tail.next:
        if next == nil:
          return false
        discard cas(addr(Q.tail), tail, next)
      else:
        value = next.value
        return true

proc free*[T](Q: ptr MsQueue[T]) =
  while true:
    var v: T
    
    if not Q.pop(v):
      break

  freeShared(Q.head)
  freeShared(Q)

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
  
  free(Q)

  # Benchmark msqueue vs Nim's channel

  Q = msqInitialize[int]()
  open(C)

  var old =  epochTime()
  for ii in 0 .. 1000000:
    Q.push(ii)
    discard Q.pop(i)
  echo "msq done"
  echo epochTime() - old

  old =  epochTime()
  for ii in 0 .. 1000000:
    C.send(ii)
    discard C.recv()

  echo "chan done"
  echo epochTime() - old
