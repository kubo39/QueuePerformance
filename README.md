# Queue Performance

## Environment

* OS

```console
$ uname -mrv
4.15.0-52-generic #56-Ubuntu SMP Tue Jun 4 22:49:08 UTC 2019 x86_64
$ cat /proc/cpuinfo| grep "model name"| head -1
model name	: Intel(R) Core(TM) i7-6500U CPU @ 2.50GHz
$ cat /proc/cpuinfo| grep processor| wc -l
4
```

* Language Versions

```console
$ dmd --version| head -1
DMD64 D Compiler v2.086.1
$ ldc -version| head -1
LDC - the LLVM D compiler (1.29.0):
$ go version
go version go1.10.3 linux/amd64
$ nim --version 2>&1| head -1
Nim Compiler Version 1.6.4 [Linux: amd64]
$ ruby -v
ruby 3.1.2p20 (2022-04-12 revision 4491bb740a) [x86_64-linux]
$ python -V
Python 3.10.4
$ rustc --version
rustc 1.60.0 (7737e0b5c 2022-04-04)
```

## Languages

### D

** **NOTE** **

DのQueue実装は動的にキューのサイズを制限できるが、実装は一般的な連結リストベースの制限なしMPSCキュー実装なのでunbounded prefixをつけている。

```console
$ rdmd -mcpu=native -O -inline dchan.d
unbounded_seq             digitalMars std.concurrency       2.2551 sec
unbounded_spsc            digitalMars std.concurrency       3.3835 sec
unbounded_mpsc            digitalMars std.concurrency       5.5216 sec
```

```console
$ ldc2 -O3 dchan.d
$ ./dchan
unbounded_seq             ldc std.concurrency       1.1444 sec
unbounded_spsc            ldc std.concurrency       1.1317 sec
unbounded_mpsc            ldc std.concurrency       3.3097 sec
```

### Go

```console
$ go run main.go
bounded0_mpmc             Go chan           1.263 sec
bounded0_mpsc             Go chan           0.942 sec
bounded0_select_both      Go chan           3.775 sec
bounded0_select_rx        Go chan           2.609 sec
bounded0_spsc             Go chan           0.894 sec
bounded1_mpmc             Go chan           1.025 sec
bounded1_mpsc             Go chan           0.749 sec
bounded1_select_both      Go chan           3.182 sec
bounded1_select_rx        Go chan           2.272 sec
bounded1_spsc             Go chan           0.703 sec
bounded_mpmc              Go chan           0.389 sec
bounded_mpsc              Go chan           0.382 sec
bounded_select_both       Go chan           1.380 sec
bounded_select_rx         Go chan           1.165 sec
bounded_seq               Go chan           0.302 sec
bounded_spsc              Go chan           0.319 sec
```

### Nim

** **NOTE** **

Nimのthreadpoolはimport時にネイティブスレッドをCPUコア数分だけ生成して、spawn関数はそのOSスレッドを使い回すので正確な比較にはならない。

```console
$ nim c -d:release nimchan.nim
(...)
$ ./nimchan
$ ./nimchan
unbounded_seq             Nim channel           0.354 sec
unbounded_spsc            Nim channel           1.1202 sec
unbounded_mpsc            Nim channel           1.1308 sec
unbounded_mpmc            Nim channel           1.1598 sec
```

### Python

```console
$ python pychan.py
unbounded_seq Python SimpleQueue 0.9366878719883971 sec
unbounded_mpsc Python SimpleQueue 0.9848010159912519 sec
unbounded_mpmc Python SimpleQueue 0.9402019499975722 sec
```

### Ruby

```console
$ ruby rbchan.rb
unbounded_seq Ruby Queue 0.8689487840165384 sec
unbounded_spsc Ruby Queue 0.8637597369961441 sec
unbounded_mpsc Ruby Queue 0.8805460979929194 sec
unbounded_mpmc Ruby Queue 0.8704172770085279 sec
```

### Rust

```console
$ cargo run --release --bin crossbeam-channel
(...)
unbounded_mpmc            Rust crossbeam-channel   0.217 sec
unbounded_mpsc            Rust crossbeam-channel   0.203 sec
unbounded_seq             Rust crossbeam-channel   0.326 sec
unbounded_spsc            Rust crossbeam-channel   0.211 sec
```
