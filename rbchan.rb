require 'thread'
require 'thwait'

MESSAGES = 5_000_000
THREADS = 4

$seq_queue = Thread::Queue.new
$spsc_queue = Thread::Queue.new
$mpsc_queue = Thread::Queue.new

def run name, f
  now = Time.now
  f.call
  elapsed = Time.now - now
  print name, ": ", elapsed, " sec\n"
end

if __FILE__ == $0
  seq = lambda do
    MESSAGES.times {|i| $seq_queue.push i }
    MESSAGES.times { $seq_queue.pop }
    $seq_queue.close
  end

  spsc = lambda do
    th1 = Thread.start {
      MESSAGES.times {|i| $spsc_queue.push i }
    }
    th2 = Thread.start {
      MESSAGES.times { $spsc_queue.pop }
    }
    th1.join
    th2.join
    $spsc_queue.close
  end

  mpsc = lambda do
    threads = []
    THREADS.times {
      threads << Thread.start {
        (MESSAGES / THREADS).times {|i|
          $mpsc_queue.push i
        }
      }
    }
    threads << Thread.start {
      MESSAGES.times { $mpsc_queue.pop }
    }
    ThreadsWait.all_waits(*threads)
    $mpsc_queue.close
  end

  run "bounded_seq", seq
  run "bounded_spsc", spsc
  run "bounded_mpsc", mpsc
end
