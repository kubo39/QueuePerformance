import os
import threadpool # spawn
import times

const MESSAGES = 5_000_000
const THREADS = 4

type IntChannel = Channel[int]
var channels: array[0..2, IntChannel]

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

proc run(name: string, f: proc()) =
  let time = epochTime()
  f()
  let elapsed = epochTime() - time
  echo name & ": ",  elapsed, " sec"

when isMainModule:
  run("bounded_seq", seque)
  run("bounded_spsc", spsc)
  run("bounded_mpsc", mpsc)
