# Day 06 — Building a Go HTTP Service

**Stripe Core Performance Preparation — Week 1**

## Objective

Build a small HTTP service in Go to understand how web servers handle requests, how Go manages concurrent connections, and how different workloads affect CPU and memory usage.

This service will form the basis of our future performance investigations using `pprof`, benchmarking, load testing, and garbage collection analysis.

## 1. Go Modules

We created our project using:

```bash
mkdir -p ~/day06-lab
cd ~/day06-lab
go mod init stripe-practice/service
```

This creates a `go.mod` file, which defines the module's identity, its Go version, and any external module dependencies.

Unlike C header files, which primarily contain declarations, `go.mod` manages module-level information and dependencies. Individual `.go` files still import the packages they need.

## 2. HTTP Server Architecture

We used Go's standard `net/http` package rather than an external web framework.

Our server starts using:

```go
http.ListenAndServe(":8080", nil)
```

- `:8080` listens on TCP port 8080, generally on all available interfaces.
- `nil` selects Go's default HTTP multiplexer, `http.DefaultServeMux`.
- `ListenAndServe` blocks while serving requests and returns when an error occurs.

Handlers are registered using:

```go
http.HandleFunc("/health", healthHandler)
```

This associates the `/health` route with a handler function. Registering a handler does not execute it immediately; it executes when a matching request arrives.

### Requests and responses

Every handler receives:

```go
func healthHandler(w http.ResponseWriter, r *http.Request)
```

`*http.Request` describes the incoming request, including its method, URL, headers, and body.

`http.ResponseWriter` is an interface used to construct and send the outgoing response, including headers, status codes, and body content.

For example:

```go
func healthHandler(w http.ResponseWriter, r *http.Request) {
    fmt.Fprintln(w, "OK")
}
```

Writing the response body without explicitly specifying a status code automatically sends `200 OK`.

To return another status code, call `w.WriteHeader(...)` before writing the body.

## 3. Implemented Endpoints

### `/health` — Basic HTTP handling

Returns `OK` to indicate that the server can respond to an HTTP request.

Test:

```bash
curl -i http://localhost:8080/health
```

The `-i` flag displays the HTTP response headers alongside the body.

A successful health response confirms that the HTTP handler is responding, but does not necessarily establish that all dependencies or downstream services are healthy.

### `/compute` — CPU-intensive workload

```go
func computeHandler(w http.ResponseWriter, r *http.Request) {
    var result uint64

    for i := uint64(0); i < 100_000_000; i++ {
        result += i * i
    }

    fmt.Fprintf(w, "Result: %d\n", result)
}
```

This endpoint is intended to simulate CPU-intensive work by repeatedly performing arithmetic.

Test:

```bash
curl -w '\nTotal time: %{time_total}s\n' \
    http://localhost:8080/compute
```

The reported duration is wall-clock time, not CPU time.

**Wall-clock time vs CPU time**

Wall-clock time measures the elapsed time between starting and finishing an operation.

CPU time measures how long the process or thread actually executed on a CPU.

An HTTP request could take 500 ms while consuming very little CPU time if most of that duration was spent waiting for I/O, locks, or scheduling.

Conversely, a multithreaded workload may accumulate more CPU time than its elapsed wall-clock duration.

**Compiler optimisation**

A compiler may simplify, transform, or eliminate calculations when it can prove the result is unchanged.

Therefore, writing a large loop does not automatically guarantee that a benchmark performs the intended amount of CPU work.

We will use profiling to examine the actual workload rather than assuming the loop's source code directly determines its runtime cost.

### `/allocate` — Memory allocation workload

```go
func allocateHandler(w http.ResponseWriter, r *http.Request) {
    data := make([][]byte, 1000)

    for i := range data {
        data[i] = make([]byte, 1024)
        data[i][0] = byte(i)
    }

    fmt.Fprintf(w, "Allocated %d buffers\n", len(data))
}
```

This endpoint is intended to create 1,000 byte buffers, each containing 1,024 bytes.

The requested buffer capacity totals approximately 1 MiB.

The outer expression:

```go
make([][]byte, 1000)
```

creates a slice containing 1,000 initially nil inner slices. It does not allocate the 1 KiB buffers themselves.

The inner expression:

```go
make([]byte, 1024)
```

creates a byte slice whose elements are initially zero.

Writing:

```go
data[i][0] = byte(i)
```

modifies the first byte of each buffer.

However, these writes alone do not guarantee that the compiler retains every allocation. Because the buffer contents are never observed after the loop, some allocations may be optimised away.

We will investigate real allocation behaviour using Go's heap profiler and escape analysis.

## 4. Go Concurrency

Go's HTTP server can handle multiple connections concurrently using goroutines.

Goroutines are lightweight units of execution managed by the Go runtime.

They are not separate operating-system processes.

The Go scheduler multiplexes goroutines onto operating-system threads.

**Concurrency vs parallelism**

- Concurrency means multiple tasks can make progress over overlapping periods.
- Parallelism means multiple tasks execute simultaneously, potentially on separate CPU cores.

With one available CPU core, CPU-bound goroutines may take turns executing.

With multiple available CPU cores, goroutines may execute simultaneously.

A blocked goroutine can allow other goroutines to continue running.

This distinction will be explored further in Day 09.

## 5. Linux Socket Inspection

We inspected the HTTP server using:

```bash
ss -ltnp 'sport = :8080'
```

Flags:

| Flag | Meaning |
|---|---|
| `-l` | Listening sockets |
| `-t` | TCP sockets |
| `-n` | Numeric addresses and ports |
| `-p` | Associated processes |

To inspect TCP sockets in all states:

```bash
ss -tanp
```

### TCP connection states

**LISTEN**

The server is waiting for incoming connections.

**ESTAB**

A TCP connection has been established between two endpoints, allowing bidirectional communication.

**TIME-WAIT**

An endpoint has actively closed a connection and temporarily retains TCP state to handle delayed packets and retransmission of the final acknowledgement.

A server may have one listening socket and many established connections simultaneously.

For example, three connected clients could correspond to one listening socket and three established sockets on the server.

## 6. Loopback and Network Accessibility

We tested the server using:

```bash
curl http://localhost:8080/health
```

`localhost` commonly resolves to the IPv4 loopback address `127.0.0.1` or the IPv6 loopback address `::1`.

Loopback traffic stays within the local network namespace.

Because our server runs inside a Colima Ubuntu environment, its loopback networking is not necessarily identical to the macOS host's networking.

The server uses `:8080`, which generally binds to all available local interfaces rather than only loopback.

However, successful access from inside the VM does not guarantee access from another computer.

External accessibility depends on network routing, VM networking, port forwarding, firewalls, and the interface to which the service is bound.

## 7. Process Management

While running the server, we accidentally pressed `Ctrl+Z`, suspending `go run` rather than terminating it.

Starting another instance produced:

```text
listen tcp :8080: bind: address already in use
```

This happened because the original server was still holding port 8080.

Useful commands:

```bash
jobs -l
fg %1
```

After returning the job to the foreground, `Ctrl+C` normally terminates it.

To investigate an occupied port:

```bash
ss -ltnp 'sport = :8080'
```

Then terminate the relevant process using its PID if necessary.

This reinforced the difference between process suspension, termination, and socket ownership.

## 8. HTTP Service Troubleshooting Guide

When an HTTP service cannot be reached, investigate systematically.

**Step 1 — Is the process running?**

```bash
ps aux | grep '[s]ervice'
```

**Step 2 — Is the expected port listening?**

```bash
ss -ltnp 'sport = :8080'
```

**Step 3 — Can the service respond locally?**

```bash
curl -v http://127.0.0.1:8080/health
```

**Step 4 — Is it bound to the correct interface?**

Inspect the local address in `ss`. A service bound only to `127.0.0.1` cannot normally accept direct connections addressed to an external interface.

**Step 5 — Is the client reaching the correct host and port?**

Inspect DNS, IP addresses, routing, firewall rules, and any VM port forwarding.

**Step 6 — Is the problem connectivity or application latency?**

Use `curl` timings and later profiling tools to distinguish connection failures from slow request processing.

## 9. Important Lessons

1. Go's `net/http` package can build a functional HTTP service without a third-party framework.
2. `ResponseWriter` constructs the response; `Request` describes the incoming request.
3. HTTP handlers execute when requests arrive, not when they are registered.
4. Wall-clock latency is not equivalent to CPU usage.
5. Goroutines allow a Go process to handle multiple connections concurrently.
6. Slices do not necessarily correspond to heap allocations.
7. Garbage collection reclaims unreachable heap objects, but not necessarily immediately.
8. Compiler optimisations can invalidate naive performance experiments.
9. Listening sockets and established TCP connections represent different stages of communication.
10. A working localhost connection does not guarantee external network accessibility.

## 10. Revision Questions

1. What is the purpose of `go.mod`?
2. What does `nil` mean in `http.ListenAndServe(":8080", nil)`?
3. What is the difference between `http.ResponseWriter` and `*http.Request`?
4. Why does writing a response body implicitly send HTTP 200?
5. How can an HTTP request take 500 ms while consuming only 2 ms of CPU time?
6. How does Go handle multiple simultaneous HTTP connections?
7. What is the difference between concurrency and parallelism?
8. What does `make([][]byte, 1000)` allocate?
9. Why doesn't leaving a function necessarily immediately free its heap allocations?
10. What is the difference between TCP LISTEN and ESTAB?
11. Why does TCP use TIME-WAIT?
12. Why might a service work on localhost but fail from another machine?

## Next — Day 07: CPU Profiling with `pprof`

We will extend this service with CPU profiling, generate load against `/compute`, and inspect where CPU time is actually being spent.

Topics include:

- Go's `runtime/pprof` and `net/http/pprof`
- CPU sampling
- Hot functions and call graphs
- Flame graphs
- Benchmark reliability
- Identifying genuine CPU bottlenecks

The objective is to move from observing that a request is slow to understanding **why it is slow and where the CPU time is going**.
