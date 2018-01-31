# Queue Performance

## Environment

* OS

```console
$ uname -mrv
4.4.0-98-generic #121-Ubuntu SMP Tue Oct 10 14:24:03 UTC 2017 x86_64
$ cat /proc/cpuinfo| grep "model name"| head -1
model name      : Intel(R) Core(TM) i7-7500U CPU @ 2.70GHz
$ cat /proc/cpuinfo| grep processor| wc -l
4
```

* Language Versions

```console
$ dmd --version| head -1
DMD64 D Compiler v2.078.0
$ ldc2 -version| head -1
LDC - the LLVM D compiler (1.7.0):
$ go version
go version go1.6.2 linux/amd64
$ nim --version 2>&1| head -1
Nim Compiler Version 0.17.2 (2017-09-07) [Linux: amd64]
$ python -V
Python 3.6.1
$ ruby -v
ruby 2.4.1p111 (2017-03-22 revision 58053) [x86_64-linux]
$ rustup run nightly rustc --version
rustc 1.25.0-nightly (def3269a7 2018-01-30)
```

## Languages

### D

** **NOTE** **

DのQueue実装は動的にキューのサイズを制限できるが、実装は一般的な連結リストベースの制限なしMPSCキュー実装なのでunbounded prefixをつけている。

```console
$ dmd -O dchan.d
$ ./dchan
unbounded_seq: 2 secs, 341 ms, 478 μs, and 4 hnsecs
unbounded_spsc: 3 secs, 236 ms, 297 μs, and 8 hnsecs
unbounded_mpsc: 3 secs, 243 ms, 889 μs, and 5 hnsecs
$ ./dchan
unbounded_seq: 1 sec, 107 ms, 251 μs, and 9 hnsecs
unbounded_spsc: 2 secs, 203 ms, 838 μs, and 8 hnsecs
unbounded_mpsc: 2 secs, 14 ms, 670 μs, and 4 hnsecs
```

```console

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
Hint: used config file '/home/kubo39/.choosenim/toolchains/nim-0.17.2/config/nim.cfg' [Conf]
Hint: used config file '/home/kubo39/dev/kubo39/nim.cfg' [Conf]
Hint: used config file '/home/kubo39/dev/kubo39/QueuePerformance/nim.cfg' [Conf]
(...)
Hint: operation successful (23907 lines compiled; 1.475 sec total; 28.027MiB peakmem; Release Build) [SuccessX]
$ ./nimchan
$ ./nimchan
unbounded_seq: 0.3609180450439453 sec
unbounded_spsc: 1.505530118942261 sec
unbounded_mpsc: 0.8148629665374756 sec
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
unbounded_seq: 0.54665814 sec
unbounded_spsc: 0.529027028 sec
unbounded_mpsc: 0.524194428 sec
```

### Rust

```console
$ rustup run nightly cargo run --release --bin crossbeam-channel
    Finished release [optimized] target(s) in 0.0 secs
     Running `target/release/crossbeam-channel`
bounded0_mpmc             Rust channel      1.240 sec
bounded0_mpsc             Rust channel      1.322 sec
bounded0_select_both      Rust channel      2.571 sec
bounded0_select_rx        Rust channel      2.169 sec
bounded0_spsc             Rust channel      1.679 sec
bounded1_mpmc             Rust channel      0.708 sec
bounded1_mpsc             Rust channel      0.909 sec
bounded1_select_both      Rust channel      1.015 sec
bounded1_select_rx        Rust channel      0.759 sec
bounded1_spsc             Rust channel      1.284 sec
bounded_mpmc              Rust channel      0.253 sec
bounded_mpsc              Rust channel      0.259 sec
bounded_select_both       Rust channel      0.524 sec
bounded_select_rx         Rust channel      0.360 sec
bounded_seq               Rust channel      0.155 sec
bounded_spsc              Rust channel      0.122 sec
unbounded_mpmc            Rust channel      0.251 sec
unbounded_mpsc            Rust channel      0.280 sec
unbounded_select_both     Rust channel      0.441 sec
unbounded_select_rx       Rust channel      0.361 sec
unbounded_seq             Rust channel      0.282 sec
unbounded_spsc            Rust channel      0.319 sec
```
