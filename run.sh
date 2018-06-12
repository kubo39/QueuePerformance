#!/bin/bash

cargo run --release --bin crossbeam-channel | tee crossbeam-channel.txt
go run go.go | tee go.txt
nim c -r -d:release nimchan.nim | tee nim.txt
rdmd -O dchan.d | tee dmd.txt
ruby rbchan.rb | tee ruby.txt

python plot.py *.txt
