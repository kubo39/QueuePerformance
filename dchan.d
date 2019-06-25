import core.thread : thread_joinAll;
import std.concurrency;
import std.conv : to;
import std.datetime.stopwatch;
import std.stdio;

enum MESSAGES = 5_000_000;
enum THREADS = 4;

void seq()
{
    foreach (int i; 0 .. MESSAGES)
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

string getCompilerString()
{
    version (DigitalMars)
        return "dmd";
    version (LDC)
        return "ldc";
    else assert(false);
}

void run(string name, void function() f)
{
    auto sw = StopWatch(AutoStart.yes);
    f();
    auto elapsed = sw.peek();
    writefln("%-25s %15s %7s.%3s sec",
             name,
             getCompilerString ~ " std.concurrency",
             elapsed.total!"seconds", elapsed.total!"msecs");
}

void main()
{
    run("unbounded_seq", &seq);
    run("unbounded_spsc", &spsc);
    run("unbounded_mpsc", &mpsc);
}
