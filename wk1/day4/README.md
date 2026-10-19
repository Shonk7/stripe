# Day 4 — Processes, Jobs, Signals and Syscall Tracing

## Goal
Explain process creation, program replacement, job control, termination and reaping; observe the corresponding Linux syscalls.

## Process identifiers and inspection
- **PID:** process ID; **PPID:** parent PID; **PGID:** process group ID; **SID:** session ID.
- A shell pipeline typically shares a PGID so signals/job control can act on the whole job.
- `$$` is the shell PID in common interactive usage; `$!` is the most recent background job's PID.

```bash
ps -p $$ -o pid,ppid,pgid,sid,stat,comm
ps -eo pid,ppid,pgid,stat,comm --forest
ps aux
top                       # q to exit
cat /proc/$$/status
ls -l /proc/$$/fd
sleep 300 &
jobs -l
```

## Linux process states
| State | Meaning |
|---|---|
| `R` | Running or runnable |
| `S` | Interruptible sleep |
| `D` | Uninterruptible sleep, often kernel I/O wait |
| `T` | Stopped (job control or tracing) |
| `Z` | Zombie: exited, not yet reaped |

## Job control and signals
```bash
sleep 600       # Ctrl+Z suspends foreground job
jobs -l
bg              # resume stopped job in background
fg              # bring job to foreground
# Ctrl+C sends SIGINT to foreground process group

sleep 700 &
pid=$!
kill -STOP "$pid"
kill -CONT "$pid"
kill -TERM "$pid"
wait "$pid"
```
- `SIGINT`: interrupt; `Ctrl+C` typically sends it to foreground process group.
- `SIGTSTP`: terminal stop; `Ctrl+Z` typically sends it.
- `SIGSTOP`: uncatchable/unblockable stop.
- `SIGCONT`: continue a stopped process.
- `SIGTERM`: termination request; can be handled, blocked or ignored.
- `SIGKILL`: cannot be caught, blocked or ignored; no user-space cleanup handler.
- `SIGCHLD`: generated when a child changes state, including termination.
- Signal a process group with `kill -TERM -- -PGID` (take care to target the right group).

## `fork()`, `exec()`, `waitpid()`
```c
pid_t pid = fork();
if (pid < 0) {
    perror("fork");
    return 1;
}
if (pid == 0) {
    execlp("sleep", "sleep", "30", (char *)NULL);
    perror("execlp");
    _exit(127);
}
int status;
if (waitpid(pid, &status, 0) == -1) {
    perror("waitpid");
    return 1;
}
if (WIFEXITED(status)) {
    printf("exit code: %d\n", WEXITSTATUS(status));
} else if (WIFSIGNALED(status)) {
    printf("signal: %d\n", WTERMSIG(status));
}
```
- `fork()` creates a child. Parent receives child PID; child receives `0`; failure returns `-1` to caller.
- `exec` replaces the calling process's program image **without creating a new PID**. On success, `exec` never returns.
- `waitpid()` can block until the child changes state, collects its status, and reaps terminated children.
- The parent and child can execute concurrently; waiting is a choice, not a requirement for all programs.
- Flush buffered stdout before `exec` if you need earlier printed output to appear.

## Zombie lifecycle
```text
Parent (running)
  |
  +-- fork() --> Child (running)
                    |
                    +-- execve() --> New program image, SAME PID
                    |
                    +-- _exit(42) --> Zombie (Z)
                                       |
Parent calls waitpid() ----------------+
                                       |
                                    Reaped
```
- A zombie has already exited; `kill -9` cannot terminate it again.
- If its parent exits, it is reparented to an appropriate reaper (often PID 1 or a subreaper) and can then be reaped.
- In the lab, the C parent's `waitpid()` reaped its child; Bash `wait "$PARENT"` waited for the background **C parent** and did not directly reap the grandchild.

## `strace` — observe real syscalls
```bash
gcc -Wall -Wextra -O0 -g lifecycle.c -o lifecycle
strace -f -e trace=process,signal -o lifecycle.strace ./lifecycle
grep -E 'clone|fork|vfork|execve|wait4|waitid|exit_group|SIGCHLD' lifecycle.strace
```
- `-f` follows children; `-e trace=process,signal` filters syscall classes; `-o` saves output.
- glibc's `fork()` wrapper may use Linux `clone()` internally; this is library implementation, not a compiler optimisation.
- glibc's `waitpid()` may use Linux `wait4()` internally.
- `execve()` installs a new program image in the same process.
- `exit_group()` terminates the calling thread group; the parent can observe child termination through `SIGCHLD` and `wait4()`.
- Trace ordering can vary due to scheduling.

## Common traps
- `Ctrl+Z` **stops** a job; it doesn't itself resume it in the background. Use `bg`.
- `SIGTERM` is not necessarily caught; its default action is termination.
- `SIGKILL` is enforced by the kernel, not by the target's parent.
- Never inspect `status` after `waitpid()` without checking for errors.
- After `exec` failure, use `_exit(...)` in the child rather than falling through into parent logic.

## Active recall
1. What are the return values of `fork()` in parent and child?
2. Why does `execve()` preserve the PID?
3. Why does `waitpid()` prevent a terminated child from remaining a zombie?
4. Why can a zombie not be killed with `SIGKILL`?
5. How do `SIGTSTP`, `SIGSTOP`, `SIGTERM` and `SIGKILL` differ?
6. Why might `strace` show `clone()` and `wait4()` when your code calls `fork()` and `waitpid()`?
7. What is the difference between Bash `wait` and C `waitpid()` in the zombie lab?

## Revisit the lab
Recompile `lifecycle.c` and `zombie.c`. Inspect the process tree, signal the child, confirm `WIFSIGNALED`, and review `lifecycle.strace` to locate process creation, exec, termination and reaping.
