import os
import strformat
import times

const MESSAGES = 5_000_000
const THREADS = 4

type IntChannel = Channel[int]
var channels: array[0..3, IntChannel]

proc seque =
  channels[0].open()
  for i in 0 .. MESSAGES - 1:
    channels[0].send(int(i))
  for i in 0 .. MESSAGES - 1:
    discard channels[0].recv()
  channels[0].close()

proc sender1 {.thread.} =
  for i in 0 .. MESSAGES - 1:
    channels[1].send(int(i))

proc receiver1 {.thread.} =
  for i in 0 .. MESSAGES - 1:
    discard channels[1].recv()

proc spsc =
  var
    spscSender: Thread[void]
    spscReceiver: Thread[void]

  channels[1].open()
  createThread(spscSender, sender1)
  createThread(spscReceiver, receiver1)
  joinThread(spscSender)
  joinThread(spscReceiver)
  channels[1].close()


proc sender2 {.thread.} =
  for i in 0 .. uint(MESSAGES / THREADS) - 1:
    channels[2].send(int(i))

proc receiver2 {.thread.} =
  for i in 0 .. MESSAGES - 1:
    discard channels[2].recv()

proc mpsc =
  var
    mpscSender: array[0 .. THREADS - 1, Thread[void]]
    mpscReceiver: Thread[void]

  channels[2].open()
  for i in 0 .. THREADS - 1:
    createThread(mpscSender[i], sender2)
  createThread(mpscReceiver, receiver2)
  joinThreads(mpscSender)
  joinThread(mpscReceiver)
  channels[2].close()


proc sender3 {.thread.} =
  for i in 0 .. uint(MESSAGES / THREADS) - 1:
    channels[3].send(int(i))

proc receiver3 {.thread.} =
  for i in 0 .. uint(MESSAGES / THREADS) - 1:
    discard channels[3].recv()

proc mpmc =
  var
    mpmcSender: array[0 .. THREADS - 1, Thread[void]]
    mpmcReceiver: array[0 .. THREADS - 1, Thread[void]]
  channels[3].open()
  for i in 0 .. THREADS - 1:
    createThread(mpmcSender[i], sender3)
  for i in 0 .. THREADS - 1:
    createThread(mpmcReceiver[i], receiver3)
  joinThreads(mpmcSender)
  joinThreads(mpmcReceiver)
  channels[3].close()

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
