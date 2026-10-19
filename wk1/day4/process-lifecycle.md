# Linux Process Lifecycle

Parent process
    |
    | fork()
    v
Child created (new PID)
    |
    | execve()
    v
New program image (same PID)
    |
    | exit() / signal termination
    v
Zombie (Z)
    |
    | Parent calls waitpid()
    v
Reaped (removed from process table)

## Key observations

- fork() creates a child process.
- execve() replaces the program image without changing PID.
- waitpid() collects termination status and reaps the child.
- SIGCHLD notifies the parent of child state changes.
- SIGTERM can be handled; SIGKILL cannot.
- A zombie has terminated but has not yet been reaped.
