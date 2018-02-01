#!/usr/bin/env python2

import sys
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

results = []
for f in sys.argv[1:]:
    with open(f) as f:
        for line in f.readlines():
            test, lang, impl, secs, _ = line.split()
            results.append((test, lang, impl, float(secs)))

fig = plt.figure(figsize=(10, 10))


def plot(subplot, title, prefix, runs):
    runs.reverse()

    ys = [7 * (i+1) for i in xrange(len(runs))]
    ax = fig.add_subplot(subplot)
    ax.set_title(title)
    ax.set_yticks(ys)
    ax.set_yticklabels(runs)
    ax.tick_params(which='major', length=0)
    ax.set_xlabel('seconds')

    rust = [0] * len(runs)
    nim = [0] * len(runs)
    dmd = [0] * len(runs)
    ruby = [0] * len(runs)

    for (i, run) in enumerate(runs):
        for (test, lang, impl, secs) in results:
            if test == prefix + '_' + run:
                if lang == 'Rust' and impl == 'channel':
                    rust[i] = secs
                if lang == 'Nim' and impl == 'channel':
                    nim[i] = secs
                if lang == 'dmd' and impl == 'std.concurrency':
                    dmd[i] = secs
                if lang == 'Ruby' and impl == 'Queue':
                    ruby[i] = secs

    opts = dict(height=0.7, align='center')
    ax.barh([y-2 for y in ys], rust, color='red', **opts)
    ax.barh([y-1 for y in ys], nim, color='black', **opts)
    ax.barh([y+0 for y in ys], dmd, color='orange', **opts)
    ax.barh([y+1 for y in ys], ruby, color='green', **opts)

    m = int(max(rust + nim + dmd + ruby) * 1.2)
    if m < 10:
        ax.set_xticks(range(m + 1))
    elif m < 50:
        ax.set_xticks([x*5 for x in range(m / 5 + 1)])
    elif m < 200:
        ax.set_xticks([x*20 for x in range(m / 20 + 1)])
    else:
        ax.set_xticks([x*100 for x in range(m / 100 + 1)])

    for (x, y) in zip(rust, ys):
        if x > 0:
            ax.text(x+m/200., y-2-0.3, 'Rust', fontsize=7)
    for (x, y) in zip(nim, ys):
        if x > 0:
            ax.text(x+m/200., y-1-0.3, 'Nim', fontsize=7)
    for (x, y) in zip(dmd, ys):
        if x > 0:
            ax.text(x+m/200., y+0-0.3, 'D', fontsize=7)
    for (x, y) in zip(ruby, ys):
        if x > 0:
            ax.text(x+m/200., y+2-0.3, 'Ruby', fontsize=7)


plot(
    221,
    "Unbounded channel",
    'unbounded',
    ['seq', 'spsc', 'mpsc', 'mpmc'],
)

legend = [
    ('Rust crossbeam-channel', 'red'),
    ('Nim channel', 'black'),
    ('dmd std.concurrency', 'orange'),
    ('Ruby Queue', 'green'),
]
legend.reverse()
fig.legend(
    [mpatches.Patch(label=label, color=color) for (label, color) in legend],
    [label for (label, color) in legend],
    'upper center',
    ncol=2,
)

plt.subplots_adjust(
    top=0.88,
    bottom=0.05,
    left=0.1,
    right=0.95,
    wspace=0.3,
    hspace=0.2,
)
plt.savefig('plot.png')
# plt.show()
