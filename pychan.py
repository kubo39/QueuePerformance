import queue
import threading
import time

MESSAGES = 5000000
THREADS = 4

seq_queue = queue.Queue()
spsc_queue = queue.Queue()
mpsc_queue = queue.Queue()

def seq():
    for i in range(0, MESSAGES):
        seq_queue.put(i)
    for i in range(0, MESSAGES):
        seq_queue.get()

def sender():
    global mpsc_queue
    for i in range(0, int(MESSAGES / THREADS)):
        mpsc_queue.put(i)

def receiver():
    global mpsc_queue
    for i in range(0, MESSAGES):
        mpsc_queue.get()

def mpsc():
    global mpsc_queue
    threads = []
    for i in range(0, THREADS):
        t = threading.Thread(target=sender)
        t.start()
        threads.append(t)
    t = threading.Thread(target=receiver)
    t.start()
    threads.append(t)
    for t in threads:
        t.join()

def run(name, f):
    now = time.time()
    f()
    elapsed = time.time() - now
    print(name, "Python Queue", elapsed, "sec")

if "__main__" == __name__:
    run("unbounded_seq", seq)
    run("unbounded_mpsc", mpsc)
