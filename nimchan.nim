import os
# import strformat
import threadpool # spawn
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
  sync()
  channels[0].close()


proc sender1 {.thread.} =
  for i in 0 .. MESSAGES - 1:
    channels[1].send(int(i))

proc receiver1 {.thread.} =
  for i in 0 .. MESSAGES - 1:
    discard channels[1].recv()

proc spsc =
  channels[1].open()
  spawn sender1()
  spawn receiver1()
  sync()
  channels[1].close()


proc sender2 {.thread.} =
  for i in 0 .. uint(MESSAGES / THREADS) - 1:
    channels[2].send(int(i))

proc receiver2 {.thread.} =
  for i in 0 .. MESSAGES - 1:
    discard channels[2].recv()

proc mpsc =
  channels[2].open()
  for _ in 0 .. THREADS - 1:
    spawn sender2()
  spawn receiver2()
  sync()
  channels[2].close()


proc sender3 {.thread.} =
  for i in 0 .. uint(MESSAGES / THREADS) - 1:
    channels[3].send(int(i))

proc receiver3 {.thread.} =
  for i in 0 .. uint(MESSAGES / THREADS) - 1:
    discard channels[3].recv()

proc mpmc =
  channels[3].open()
  for _ in 0 .. THREADS - 1:
    spawn sender3()
  for _ in 0 .. THREADS - 1:
    spawn receiver3()
  sync()
  channels[3].close()


proc run(name: string, f: proc()) =
  let time = epochTime()
  f()
  let elapsed = epochTime() - time
#  echo &"""{name:<25} {"Nim channel":<15} {elapsed:7.3} sec"""
  echo name & " Nim channel ",  elapsed, " sec"

when isMainModule:
  run("unbounded_seq", seque)
  run("unbounded_spsc", spsc)
  run("unbounded_mpsc", mpsc)
  run("unbounded_mpmc", mpmc)
