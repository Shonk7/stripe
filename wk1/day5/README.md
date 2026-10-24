# Day 5 — The `/proc` Filesystem and System Inspection

**Week 1: Linux command line and system investigation**  
**Goal:** Investigate an unfamiliar Linux process using kernel-provided process information, distinguish virtual and physical memory usage, and produce a repeatable diagnostic report.

## What we did

1. Explored the virtual `/proc` filesystem and inspected process metadata with `/proc/<PID>/status`, `ps`, and `free`.
2. Wrote `memory.c` to reserve 256 MiB with `mmap()`, pause, then write to one location per page. Compared `VmSize` and `VmRSS` before and after the writes.
3. Wrote `compare.c` with a sleeping mode and a CPU-bound mode. Compared process states, CPU time, and voluntary/nonvoluntary context switches using `ps`, `/proc/<PID>/status`, and `pidstat`.
4. Inspected `/proc/<PID>/maps`, `smaps`, and `fd` to understand virtual memory areas, proportional memory accounting, and open file descriptors.
5. Built `diagnose-process.sh` to generate a per-process report from `/proc`.

## 1. Understanding `/proc`

`/proc` (procfs) is a **virtual/pseudo filesystem**: the kernel exposes live process and system information through paths that look like ordinary files. These are not persistent disk files. Virtual *filesystem* does **not** mean that every byte is stored in a process's virtual memory.

Useful paths:

| Path | What it shows |
| --- | --- |
| `/proc/<PID>/status` | Human-readable state, parent PID, thread count, memory figures, context switches |
| `/proc/<PID>/stat` | Compact numeric process counters, including user/system CPU time |
| `/proc/<PID>/maps` | One line per virtual memory area (VMA) |
| `/proc/<PID>/smaps` | Per-VMA memory accounting: Size, Rss, Pss, private/shared pages |
| `/proc/<PID>/fd/` | Symlinks for open file descriptors |
| `/proc/meminfo` | System-wide memory counters |
| `/proc/stat` | System-wide CPU and other counters |

```bash
PID=$$
grep -E '^(Name|State|Pid|PPid|Threads|VmSize|VmRSS):' "/proc/$PID/status"
ps -p "$PID" -o pid,ppid,stat,vsz,rss,nlwp,comm
free -h
```

`$$` is the current shell's PID. `/proc` values are snapshots: processes can exit or change state while you inspect them.

## 2. Virtual memory vs physical memory

- **VmSize / VSZ:** Total mapped virtual address space of a process. This does **not** imply that all pages occupy RAM or swap.
- **VmRSS / RSS:** Approximate amount of the process's pages currently resident in physical memory; includes shared pages and is not a measure of how recently they were used.
- **VmPeak:** Peak virtual memory size.
- **VmHWM:** Peak resident set size (high-water mark).
- **PSS:** Proportional Set Size. Shared resident pages are divided among processes sharing them, so summing PSS is often more informative than summing RSS.
- **MemFree vs MemAvailable:** Linux uses otherwise idle RAM for caches. `MemAvailable` estimates how much memory can be used without swapping; low `MemFree` alone does not imply memory pressure.

**Example:** If two processes share the same 100 MiB of physical pages, each can report 100 MiB RSS for those pages, but each gets about 50 MiB PSS (assuming exactly two sharers). That does **not** consume 200 MiB of unique RAM.

### Our `mmap()` experiment (`memory.c`)

We mapped **256 MiB** of private anonymous writable virtual address space:

```c
int *mp = mmap(NULL, SIZE, PROT_READ | PROT_WRITE,
               MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
if (mp == MAP_FAILED) { perror("mmap"); return 1; }
```

We paused to inspect the process, then wrote to each page. Because `mp` is an `int *`, array indexing advances in units of `sizeof(int)`, not bytes:

```c
long page_size = sysconf(_SC_PAGESIZE);
for (size_t offset = 0; offset < SIZE; offset += (size_t)page_size) {
    mp[offset / sizeof(int)] = 0x41;
}
```

Alternatively, use a `char *` and write `mp[offset]` for byte offsets. Accessing `int_ptr[offset]` directly would advance `offset * sizeof(int)` bytes and could run beyond the mapping.

**Measured results from our lab:**

| Counter | After `mmap`, before writes | After writing every page |
| --- | ---: | ---: |
| VmSize | 264,396 kB | 264,396 kB |
| VmRSS | 1,388 kB | 263,532 kB |
| VmPeak | 264,396 kB | 264,396 kB |
| VmHWM | 1,388 kB | 263,532 kB |

The RSS increase was **262,144 KiB = 256 MiB**, while virtual size stayed constant. Linux had established the virtual mapping immediately but generally deferred allocating physical pages until first write. Those first accesses cause **page faults**; a page fault does **not** necessarily involve disk I/O. Reading untouched anonymous pages may use a shared read-only zero page, so reading each page does not necessarily allocate 256 MiB of private physical RAM.

```bash
./memory                         # leave paused at each getchar()
PID=$(pgrep -n memory)
grep -E '^(VmSize|VmRSS|VmPeak|VmHWM):' "/proc/$PID/status"
```

## 3. Sleeping vs CPU-bound processes (`compare.c`)

Our program had two modes:

- `./compare sleep`: repeatedly calls `sleep(1)` and spends most of its lifetime blocked.
- `./compare cpu`: repeatedly increments a `volatile` counter and consumes CPU cycles.

```bash
./compare sleep & SLEEP_PID=$!
./compare cpu & CPU_PID=$!

ps -p "$SLEEP_PID","$CPU_PID" -o pid,stat,%cpu,time,vsz,rss,nlwp,comm
pidstat -u -p "$SLEEP_PID","$CPU_PID" 1 5

grep -E '^(State|Threads|voluntary_ctxt_switches|nonvoluntary_ctxt_switches):' \
    "/proc/$SLEEP_PID/status"

grep -E '^(State|Threads|voluntary_ctxt_switches|nonvoluntary_ctxt_switches):' \
    "/proc/$CPU_PID/status"

kill "$SLEEP_PID" "$CPU_PID"
wait "$SLEEP_PID" "$CPU_PID" 2>/dev/null
```

**Interpretation:**

- `S` = interruptible sleep (e.g., waiting on a timer); `R` = executing **or runnable**, not necessarily on a CPU at the precise instant sampled.
- **Voluntary context switch:** the task blocks/yields, commonly when sleeping or waiting for I/O.
- **Nonvoluntary context switch:** the scheduler preempts the task. A CPU-bound loop tends to accumulate these.
- **Wall-clock time ≠ CPU time.** A task alive for 60 seconds might use only 2 seconds of CPU time because it was blocked, sleeping, or waiting to be scheduled.
- `ps %CPU` often represents a lifetime average; `pidstat` can report utilisation over a sampling interval.
- CPU time is split into **utime** (user-mode execution) and **stime** (kernel-mode execution). A busy user-space loop generally accumulates mostly `utime`.

## 4. `/proc/<PID>/stat` and CPU tick conversion

`/proc/<PID>/stat` uses positional fields:

| Original field | Meaning |
| --- | --- |
| 3 | State |
| 14 | `utime` — user CPU time in clock ticks |
| 15 | `stime` — system CPU time in clock ticks |
| 20 | Number of threads |
| 22 | Start time since boot, in clock ticks |
| 23 | Virtual memory size in bytes |
| 24 | Resident set size in pages |

**Parsing pitfall:** Field 2 is the command name in parentheses, and it may contain spaces. Naively using `awk '{print $14}'` on the raw line can shift positions. We stripped everything through the last `) `, then parsed the remaining fields:

```bash
STAT="/proc/$PID/stat"
sed 's/^.*) //' "$STAT" | awk -v hz="$(getconf CLK_TCK)" '
{
    printf "User CPU time: %.2f seconds\n", $12 / hz
    printf "System CPU time: %.2f seconds\n", $13 / hz
}'
```

After stripping original fields 1–2, `utime` becomes `$12` and `stime` becomes `$13`.

`CPU seconds = CPU ticks / CLK_TCK`. `getconf CLK_TCK` gets the relevant tick rate (often 100, but do not hardcode it).

**Shell quoting pitfall:**

```bash
awk "{print($12)}" "$STAT"  # WRONG: Bash expands $1, then leaves literal 2
awk '{print($12)}' "$STAT"  # AWK receives $12 as intended
```

`sysconf(_SC_CLK_TCK)` is a C library call, **not** an AWK function. Pass `getconf CLK_TCK` to AWK using `-v`.

## 5. Memory mappings: `maps` vs `smaps`

```bash
cat "/proc/$PID/maps"
less "/proc/$PID/smaps"
wc -l < "/proc/$PID/maps"   # Count VMAs
```

A **VMA** is a contiguous range of virtual addresses with shared mapping attributes. One VMA may span thousands of pages. In `maps`, each line contains an address range, permissions (`rwx`, `p` private or `s` shared), offset, device/inode, and optional backing path.

`smaps` adds memory-accounting details for each mapping. Its `Rss` shows resident memory for the region, and `Pss` accounts proportionally for shared resident pages. A VMA appears in `maps` even if its pages haven't been physically allocated yet.

## 6. Open file descriptors: `/proc/<PID>/fd`

```bash
ls -l "/proc/$PID/fd/"
readlink "/proc/$PID/fd/0"
```

Entries `0`, `1`, `2` conventionally represent stdin, stdout and stderr. Each entry is a symlink to the underlying open object. The next opened file usually gets the lowest available descriptor, often `3`.

We observed entries such as `/dev/pts/1 (deleted)`. This means the pathname/device entry disappeared while the process still held open references. Deleting a path does not automatically close existing file descriptors.

```bash
for fd in /proc/"$PID"/fd/*; do
    [[ -e "$fd" || -L "$fd" ]] || continue
    fd_num=${fd##*/}
    target=$(readlink "$fd") || continue
    printf '%s -> %s\n' "$fd_num" "$target"
done
```

- `[[ -e "$fd" || -L "$fd" ]]` checks for an existing target **or** a symlink, including a broken one; it also skips an unmatched `*` glob.
- `${fd##*/}` removes the longest prefix ending in `/`, leaving the descriptor number.
- `$(readlink "$fd")` captures the symlink target.
- `|| continue` skips entries that disappear during inspection.
- `-L` is a test operator inside `[[ ... ]]`, not a standalone command.

## 7. Diagnostic script (`diagnose-process.sh`)

**Goal:** Accept a PID and report process identity/state, memory usage, user/system CPU time, context switches, open FDs, and VMA count.

```bash
./diagnose-process.sh "$PID"
```

Implementation choices we discussed:

- Validate the number of arguments, numeric PID format, and `/proc/<PID>` existence.
- Read `Name`, `State`, `PPid`, `Threads`, `VmSize`, `VmRSS`, `VmPeak`, `VmHWM`, and context-switch counters from `status`.
- Read `utime`/`stime` from `stat`, taking care with the parenthesised process name.
- Iterate over `fd/*` and use `readlink` to show targets.
- Count lines in `maps` for the VMA count.
- Handle process exits and permission errors gracefully: `/proc` can change while a report is being collected.

**Important fix:** Use `set -euo pipefail`, **not** `set -l euo pipefail`.

Prefer precise anchored `grep` patterns and avoid unnecessary `echo "$(...)"` wrappers:

```bash
grep -E '^(Name|State|PPid|Threads):' "$STATUS"
grep -E '^(VmSize|VmRSS|VmPeak|VmHWM):' "$STATUS"
```

Our final full script was not pasted in the chat, so the remaining sections still need local verification before claiming all report fields work.

## 8. Revision questions (answer without notes)

1. Why is `/proc` a pseudo-filesystem, and what does it expose?
2. How can `VmSize` be hundreds of MiB while `VmRSS` is only a few MiB?
3. Why did writing one byte per page increase RSS by approximately 256 MiB?
4. Why might reading an untouched anonymous page not allocate a private page?
5. What is the difference between RSS and PSS when processes share memory?
6. Why is `MemAvailable` usually more useful than `MemFree`?
7. Why does a sleeping process accumulate wall-clock time but almost no CPU time?
8. What causes voluntary vs nonvoluntary context switches?
9. How are `utime` and `stime` converted from ticks to seconds?
10. Why is raw whitespace splitting of `/proc/PID/stat` unsafe?
11. What does one line in `maps` represent? How does `smaps` differ?
12. Why can `/proc/PID/fd/1` exist as a symlink even when `-e` is false?
13. What do `${fd##*/}`, `$(readlink "$fd")`, and `|| continue` do?
14. Why might process statistics disagree when sampled at different times?

## 9. Deliverables and commit

```text
wk1/day5/
├── README.md
├── memory.c
├── compare.c
└── diagnose-process.sh
```

In the Colima VM, copy the source files to the shared macOS path (if that path is mounted):

```bash
mkdir -p /Users/aryan/code/stripe-practice/wk1/day5
cp ~/day05-lab/{memory.c,compare.c,diagnose-process.sh} \
  /Users/aryan/code/stripe-practice/wk1/day5/
```

Then on macOS:

```bash
cd ~/code/stripe-practice
git add wk1/day5/
git commit -m "Complete Day 5 proc filesystem and diagnostics lab"
```

### References

- [`proc(5)`](https://man7.org/linux/man-pages/man5/proc.5.html)
- [`proc_pid_status(5)`](https://man7.org/linux/man-pages/man5/proc_pid_status.5.html)
- [`proc_pid_stat(5)`](https://man7.org/linux/man-pages/man5/proc_pid_stat.5.html)
