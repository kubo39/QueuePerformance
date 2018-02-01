#!/bin/bash

rustup run nightly cargo run --release --bin crossbeam-channel | tee channel.txt
nim c -r -d:release nimchan.nim | tee nim.txt
rdmd -O dchan.d | tee dmd.txt
ruby rbchan.rb | tee ruby.txt
./plot.py *.txt
