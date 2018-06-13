# Queue Performance

## Environment

* OS

```console
$ uname -mrv
4.13.0-43-generic #48~16.04.1-Ubuntu SMP Thu May 17 12:56:46 UTC 2018 x86_64
$ cat /proc/cpuinfo| grep "model name"| head -1
model name	: Intel(R) Core(TM) i7-6500U CPU @ 2.50GHz
$ cat /proc/cpuinfo| grep processor| wc -l
4
```

* Language Versions

```console
$ dmd --version| head -1
DMD64 D Compiler v2.080.1
$ go version
go version go1.10.3 linux/amd64
$ nim --version 2>&1| head -1
Nim Compiler Version 0.18.0 [Linux: amd64]
$ ruby -v
ruby 2.5.1p57 (2018-03-29 revision 63029) [x86_64-linux]
$ rustc --version
rustc 1.26.2 (594fb253c 2018-06-01)
```

## Languages

### D

** **NOTE** **

DのQueue実装は動的にキューのサイズを制限できるが、実装は一般的な連結リストベースの制限なしMPSCキュー実装なのでunbounded prefixをつけている。

```console
$ rdmd -O dchan.d
unbounded_seq             digitalMars std.concurrency       2.2267 sec
unbounded_spsc            digitalMars std.concurrency       3.3386 sec
unbounded_mpsc            digitalMars std.concurrency       3.3224 sec
$ ldc2 -O dchan.d
$ ./dchan
unbounded_seq             llvm std.concurrency       1.1673 sec
unbounded_spsc            llvm std.concurrency       2.2086 sec
unbounded_mpsc            llvm std.concurrency       2.2002 sec
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
unbounded_seq             Nim channel       0.465 sec
unbounded_spsc            Nim channel        1.17 sec
unbounded_mpsc            Nim channel        1.31 sec
unbounded_mpmc            Nim channel        2.35 sec
```

### Python

** **NOTE** **

PythonのQueue実装はPythonで書かれている。

```console
$ python pychan.py
unbounded_seq : 18.500499963760376 sec
unbounded_mpsc : 27.514017581939697 sec
```

### Ruby

```console
$ ruby rbchan.rb
unbounded_seq Ruby Queue 0.63472069 sec
unbounded_spsc Ruby Queue 0.580684254 sec
unbounded_mpsc Ruby Queue 0.591327483 sec
unbounded_mpmc Ruby Queue 0.223464353 sec
```

### Rust

```console
$ rustup run nightly cargo run --release --bin crossbeam-channel
    Finished release [optimized] target(s) in 0.0 secs
     Running `target/release/crossbeam-channel`
unbounded_mpmc            Rust channel      0.274 sec
unbounded_mpsc            Rust channel      0.342 sec
unbounded_seq             Rust channel      0.361 sec
unbounded_spsc            Rust channel      0.332 sec
```
