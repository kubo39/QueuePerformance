// from https://github.com/crossbeam-rs/crossbeam-channel benchmark script.

extern crate crossbeam;
extern crate crossbeam_channel;

use crossbeam_channel::{bounded, unbounded, Select, Receiver, Sender};

const MESSAGES: usize = 5_000_000;
const THREADS: usize = 4;

type TxRx = (Sender<i32>, Receiver<i32>);

fn seq<F: Fn() -> TxRx>(make: F) {
    let (tx, rx) = make();

    for i in 0..MESSAGES {
        tx.send(i as i32).unwrap();
    }
    for _ in 0..MESSAGES {
        rx.recv().unwrap();
    }
}

fn spsc<F: Fn() -> TxRx>(make: F) {
    let (tx, rx) = make();

    crossbeam::scope(|s| {
        s.spawn(|| {
            for i in 0..MESSAGES {
                tx.send(i as i32).unwrap();
            }
        });
        s.spawn(|| {
            for _ in 0..MESSAGES {
                rx.recv().unwrap();
            }
        });
    });
}

fn mpsc<F: Fn() -> TxRx>(make: F) {
    let (tx, rx) = make();

    crossbeam::scope(|s| {
        for _ in 0..THREADS {
            s.spawn(|| {
                for i in 0..MESSAGES / THREADS {
                    tx.send(i as i32).unwrap();
                }
            });
        }
        s.spawn(|| {
            for _ in 0..MESSAGES {
                rx.recv().unwrap();
            }
        });
    });
}

fn mpmc<F: Fn() -> TxRx>(make: F) {
    let (tx, rx) = make();

    crossbeam::scope(|s| {
        for _ in 0..THREADS {
            s.spawn(|| {
                for i in 0..MESSAGES / THREADS {
                    tx.send(i as i32).unwrap();
                }
            });
        }
        for _ in 0..THREADS {
            s.spawn(|| {
                for _ in 0..MESSAGES / THREADS {
                    rx.recv().unwrap();
                }
            });
        }
    });
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
                "Rust channel",
                elapsed.as_secs() as f64 + elapsed.subsec_nanos() as f64 / 1e9
            );
        }
    }

    run!("unbounded_mpmc", mpmc(|| unbounded()));
    run!("unbounded_mpsc", mpsc(|| unbounded()));
    run!("unbounded_seq", seq(|| unbounded()));
    run!("unbounded_spsc", spsc(|| unbounded()));
}
