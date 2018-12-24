import queue
import threading
import time

MESSAGES = 5000000
THREADS = 4

seq_queue = queue.Queue()
spsc_queue = queue.Queue()
mpsc_queue = queue.Queue()
mpmc_queue = queue.Queue()

def seq():
    for i in range(0, MESSAGES):
        seq_queue.put(i)
    for i in range(0, MESSAGES):
        seq_queue.get()

def mpsc_sender():
    global mcsc_queue
    for i in range(0, int(MESSAGES / THREADS)):
        mpsc_queue.put(i)

def mpsc_receiver():
    global mpsc_queue
    for i in range(0, MESSAGES):
        mpsc_queue.get()

def mpsc():
    global mpsc_queue
    threads = []
    for i in range(0, THREADS):
        t = threading.Thread(target=mpsc_sender)
        t.start()
        threads.append(t)
    t = threading.Thread(target=mpsc_receiver)
    t.start()
    threads.append(t)
    for t in threads:
        t.join()

def mpmc_sender():
    global mcsc_queue
    for i in range(0, int(MESSAGES / THREADS)):
        mpmc_queue.put(i)

def mpmc_receiver():
    global mpmc_queue
    for i in range(0, int(MESSAGES / THREADS)):
        mpmc_queue.get()

def mpmc():
    global mpmc_queue
    threads = []
    for i in range(0, THREADS):
        t = threading.Thread(target=mpmc_sender)
        t.start()
        threads.append(t)
    for i in range(0, THREADS):
        t = threading.Thread(target=mpmc_receiver)
        t.start()
        threads.append(t)
    for t in threads:
        t.join()

def run(name, f):
    now = time.perf_counter()
    f()
    elapsed = time.perf_counter() - now
    print(name, "Python Queue", elapsed, "sec")

if "__main__" == __name__:
    run("unbounded_seq", seq)
    run("unbounded_mpsc", mpsc)
    run("unbounded_mpmc", mpmc)
