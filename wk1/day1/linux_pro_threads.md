# Day 1: Linux Processa and Threads

### What is a process?
A prcoess is a running instance of a program. It has its own virtual aaddress space and resoruces.\
A program which is on disk is loaded into memory (lazily in modern OS) such that the execution/process can run.

### Process States
A process can be in some states:

- Running
- Ready
- Blocked

Processes can be scheduled using a scheduler. This needs to make decisions on which processes to priortisie and whether to switch back to a blocked process once its i/o has completed.

### Process vs threads
| Process | Thread |
|---|---|
| Own virtual address space | Shares process address space |
| Stronger memory isolation | Easier shared-memory communication |
| Typically more expensive to create | Typically cheaper to create |
| Has its own resources | Shares many process resources |

### colima
To run linux on macos we use colima
```
colima start --cpu 2 --memory 4
colima ssh

sudo apt-get update
sudo apt-get install -y \
    build-essential \
    strace \
    procps \
    sysstat
```

## Exercises

### Exercise A: Inspect a running process
``` 
sleep 300 &
PID=$!

echo "PID: $PID"
ps -p "$PID" -o pid,ppid,stat,%cpu,%mem,comm
cat /proc/$PID/status | head -30
```

& means the process runs in the background \
=$! assigns the process id of the previous process to the variable PID

Results from ps -p
| PID | PPID |  STAT | %CPU|  %MEM |  COMMAND |
|---|---|---|---|---|---|  
| 5755  | 1866 |  S| 0.0|  0.0 |  sleep |

Ran process status for the porcess gave us how its using no cpu no memory, and is in the sleepign state. PPID - parent 