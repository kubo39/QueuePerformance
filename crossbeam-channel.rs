// from https://github.com/crossbeam-rs/crossbeam-channel benchmark script.
extern crate crossbeam;
extern crate crossbeam_channel;

use crossbeam_channel::{bounded, unbounded, Receiver, Select, Sender};

#[derive(Debug, Clone, Copy)]
pub struct Message(i32);

#[inline]
pub fn message(msg: usize) -> Message {
    Message(msg as i32)
}

#[allow(dead_code)]
pub fn shuffle<T>(v: &mut [T]) {
    use std::cell::Cell;
    use std::num::Wrapping;

    let len = v.len();
    if len <= 1 {
        return;
    }

    thread_local! {
        static RNG: Cell<Wrapping<u32>> = Cell::new(Wrapping(1));
    }

    RNG.with(|rng| {
        for i in 1..len {
            // This is the 32-bit variant of Xorshift.
            // https://en.wikipedia.org/wiki/Xorshift
            let mut x = rng.get();
            x ^= x << 13;
            x ^= x >> 17;
            x ^= x << 5;
            rng.set(x);

            let x = x.0;
            let n = i + 1;

            // This is a fast alternative to `let j = x % n`.
            // https://lemire.me/blog/2016/06/27/a-fast-alternative-to-the-modulo-reduction/
            let j = ((x as u64 * n as u64) >> 32) as u32 as usize;

            v.swap(i, j);
        }
    });
}

const MESSAGES: usize = 5_000_000;
const THREADS: usize = 4;

fn new<T>(cap: Option<usize>) -> (Sender<T>, Receiver<T>) {
    match cap {
        None => unbounded(),
        Some(cap) => bounded(cap),
    }
}

fn seq(cap: Option<usize>) {
    let (tx, rx) = new(cap);

    for i in 0..MESSAGES {
        tx.send(message(i)).unwrap();
    }

    for _ in 0..MESSAGES {
        rx.recv().unwrap();
    }
}

fn spsc(cap: Option<usize>) {
    let (tx, rx) = new(cap);

    crossbeam::scope(|s| {
        s.spawn(|_| {
            for i in 0..MESSAGES {
                tx.send(message(i)).unwrap();
            }
        });

        for _ in 0..MESSAGES {
            rx.recv().unwrap();
        }
    }).unwrap();
}

fn mpsc(cap: Option<usize>) {
    let (tx, rx) = new(cap);

    crossbeam::scope(|s| {
        for _ in 0..THREADS {
            s.spawn(|_| {
                for i in 0..MESSAGES / THREADS {
                    tx.send(message(i)).unwrap();
                }
            });
        }

        for _ in 0..MESSAGES {
            rx.recv().unwrap();
        }
    }).unwrap();
}

fn mpmc(cap: Option<usize>) {
    let (tx, rx) = new(cap);

    crossbeam::scope(|s| {
        for _ in 0..THREADS {
            s.spawn(|_| {
                for i in 0..MESSAGES / THREADS {
                    tx.send(message(i)).unwrap();
                }
            });
        }

        for _ in 0..THREADS {
            s.spawn(|_| {
                for _ in 0..MESSAGES / THREADS {
                    rx.recv().unwrap();
                }
            });
        }
    }).unwrap();
}

fn select_rx(cap: Option<usize>) {
    let chans = (0..THREADS).map(|_| new(cap)).collect::<Vec<_>>();

    crossbeam::scope(|s| {
        for (tx, _) in &chans {
            let tx = tx.clone();
            s.spawn(move |_| {
                for i in 0..MESSAGES / THREADS {
                    tx.send(message(i)).unwrap();
                }
            });
        }

        for _ in 0..MESSAGES {
            let mut sel = Select::new();
            for (_, rx) in &chans {
                sel.recv(rx);
            }
            let case = sel.select();
            let index = case.index();
            case.recv(&chans[index].1).unwrap();
        }
    }).unwrap();
}

fn select_both(cap: Option<usize>) {
    let chans = (0..THREADS).map(|_| new(cap)).collect::<Vec<_>>();

    crossbeam::scope(|s| {
        for _ in 0..THREADS {
            s.spawn(|_| {
                for i in 0..MESSAGES / THREADS {
                    let mut sel = Select::new();
                    for (tx, _) in &chans {
                        sel.send(tx);
                    }
                    let case = sel.select();
                    let index = case.index();
                    case.send(&chans[index].0, message(i)).unwrap();
                }
            });
        }

        for _ in 0..THREADS {
            s.spawn(|_| {
                for _ in 0..MESSAGES / THREADS {
                    let mut sel = Select::new();
                    for (_, rx) in &chans {
                        sel.recv(rx);
                    }
                    let case = sel.select();
                    let index = case.index();
                    case.recv(&chans[index].1).unwrap();
                }
            });
        }
    }).unwrap();
}

fn main() {
    macro_rules! run {
        ($name:expr, $f:expr) => {
            let now = ::std::time::Instant::now();
            $f;
            let elapsed = now.elapsed();
            println!(
                "{:25} {:15} {:7.3} sec",
                $name,
                "Rust crossbeam-channel",
                elapsed.as_secs() as f64 + elapsed.subsec_nanos() as f64 / 1e9
            );
        }
    }

    run!("bounded0_mpmc", mpmc(Some(0)));
    run!("bounded0_mpsc", mpsc(Some(0)));
    run!("bounded0_select_both", select_both(Some(0)));
    run!("bounded0_select_rx", select_rx(Some(0)));
    run!("bounded0_spsc", spsc(Some(0)));

    run!("bounded1_mpmc", mpmc(Some(1)));
    run!("bounded1_mpsc", mpsc(Some(1)));
    run!("bounded1_select_both", select_both(Some(1)));
    run!("bounded1_select_rx", select_rx(Some(1)));
    run!("bounded1_spsc", spsc(Some(1)));

    run!("bounded_mpmc", mpmc(Some(MESSAGES)));
    run!("bounded_mpsc", mpsc(Some(MESSAGES)));
    run!("bounded_select_both", select_both(Some(MESSAGES)));
    run!("bounded_select_rx", select_rx(Some(MESSAGES)));
    run!("bounded_seq", seq(Some(MESSAGES)));
    run!("bounded_spsc", spsc(Some(MESSAGES)));

    run!("unbounded_mpmc", mpmc(None));
    run!("unbounded_mpsc", mpsc(None));
    run!("unbounded_select_both", select_both(None));
    run!("unbounded_select_rx", select_rx(None));
    run!("unbounded_seq", seq(None));
    run!("unbounded_spsc", spsc(None));
}
