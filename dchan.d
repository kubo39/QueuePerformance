import core.thread : thread_joinAll;
import std.concurrency;
import std.conv : to;
import std.datetime.stopwatch;
import std.stdio;

immutable size_t MESSAGES = 5_000_000;
immutable size_t THREADS = 4;

void seq()
{
    foreach (i; 0 .. MESSAGES)
        thisTid.send(cast(int) i);
    foreach (_; 0 .. MESSAGES)
        receiveOnly!int;
}

void spsc()
{
    auto receiver = spawn({
            foreach (_; 0 .. MESSAGES)
                receiveOnly!int;
        });

    spawn((Tid tid) {
            foreach (i; 0 .. MESSAGES)
                tid.send(cast(int) i);
        }, receiver);
    thread_joinAll;
}

void mpsc()
{
    auto receiver = spawn({
            foreach (_; 0 .. MESSAGES)
                receiveOnly!int;
        });
    foreach (_; 0 .. THREADS)
        spawn((Tid tid) {
                foreach (i; 0 .. MESSAGES / THREADS)
                    tid.send(cast(int) i);
            }, receiver);
    thread_joinAll;
}

void run(string name, void function() f)
{
    auto sw = StopWatch(AutoStart.yes);
    f();
    auto elapsed = sw.peek();
    writeln(name ~ ": " ~ elapsed.to!string);
}

void main()
{
    run("unbounded_seq", &seq);
    run("unbounded_spsc", &spsc);
    run("unbounded_mpsc", &mpsc);
}
