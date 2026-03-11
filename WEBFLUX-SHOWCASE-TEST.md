# WebFlux Showcase Test

This guide introduces a dedicated API and benchmark scenario designed to highlight a core strength of `Spring WebFlux`: **handling large numbers of waiting requests without tying up a thread per request**.

## Why the existing benchmark does not fully show WebFlux value

Most of the current benchmark endpoints use blocking work through [common/src/main/java/com/performance/common/DatabaseSimulator.java](common/src/main/java/com/performance/common/DatabaseSimulator.java).

That is useful for comparing:
- `Traditional MVC`
- `Virtual Threads`
- `WebFlux` wrapping blocking work

But it does **not** fully demonstrate the case where `WebFlux` is strongest: **true non-blocking waits and true non-blocking I/O**.

## New API: `GET /api/wait/{delayMs}`

A new endpoint has been added to all three implementations:

- [spring-mvc-traditional/src/main/java/com/performance/mvc/PerformanceController.java](spring-mvc-traditional/src/main/java/com/performance/mvc/PerformanceController.java)
- [spring-virtual-threads/src/main/java/com/performance/virtual/PerformanceController.java](spring-virtual-threads/src/main/java/com/performance/virtual/PerformanceController.java)
- [spring-webflux/src/main/java/com/performance/webflux/PerformanceController.java](spring-webflux/src/main/java/com/performance/webflux/PerformanceController.java)

### Behavior by implementation

#### `Traditional MVC`
Uses `Thread.sleep(delayMs)` inside the request handler.

Result:
- one platform thread is held while the request waits
- throughput will eventually be limited by the Tomcat thread pool

#### `Virtual Threads`
Also uses `Thread.sleep(delayMs)`, but the request runs on a virtual thread.

Result:
- the code stays blocking and simple
- it scales much better than MVC for waiting workloads
- but it still models a blocking request lifecycle

#### `WebFlux`
Uses `Mono.delay(Duration.ofMillis(delayMs))`.

Result:
- the wait is non-blocking
- the server does not need to hold one blocked thread per waiting request
- thread count and memory pressure should stay much lower under high concurrency

## Why this API is a good WebFlux showcase

This endpoint isolates one of the cleanest reactive scenarios:

- lots of concurrent requests
- minimal CPU work
- mostly waiting time
- no blocking database simulator involved

That makes it much easier to show the architectural difference between:
- blocking request handling
- blocking request handling on virtual threads
- non-blocking reactive request handling

## Additional API: `GET /api/sse/{events}?intervalMs=M`

To highlight another natural strength of `WebFlux`, the project now also includes an SSE endpoint.

### Why this API matters

`WebFlux` stands out most clearly when the server needs to keep many connections open and emit data over time without blocking a worker thread per connection.

That is exactly what `SSE` and reactive streams are good at.

### Behavior by implementation

- `Traditional MVC`: uses `SseEmitter` and keeps a request open with platform-thread-oriented processing
- `Virtual Threads`: also keeps a request open, but virtual threads make the cost of waiting lower
- `WebFlux`: emits the stream with `Flux.interval(...)`, which maps naturally to reactive streaming

### Functional test

```bash
curl -N http://localhost:8080/api/sse/5?intervalMs=1000
curl -N http://localhost:8081/api/sse/5?intervalMs=1000
curl -N http://localhost:8082/api/sse/5?intervalMs=1000
```

### What this scenario is good for

- dashboards
- notification streams
- activity feeds
- server push style updates
- many concurrent waiting clients

## Recommended benchmark design

### Scenario goal

Show how each model behaves when many requests are mostly waiting rather than computing.

### Test parameters

Recommended starting point:

- delay: `1000ms`
- duration: `60s`
- threads: `8`
- concurrency levels:
  - `200`
  - `1000`
  - `3000`
  - `5000`

### Endpoints

For local runs:
- MVC: `http://localhost:8080/api/wait/1000`
- Virtual Threads: `http://localhost:8081/api/wait/1000`
- WebFlux: `http://localhost:8082/api/wait/1000`

For Kubernetes ingress runs:
- MVC: `http://${LB_IP}/mvc/api/wait/1000`
- Virtual Threads: `http://${LB_IP}/virtual/api/wait/1000`
- WebFlux: `http://${LB_IP}/webflux/api/wait/1000`

## Benchmark script

Use [test-webflux-showcase.sh](test-webflux-showcase.sh).

Example:

```bash
chmod +x test-webflux-showcase.sh
./test-webflux-showcase.sh 8 2000 60 1000 http://${LB_IP}
```

Arguments:

1. `threads`
2. `connections`
3. `durationSeconds`
4. `delayMs`
5. `baseUrl`

Example for ingress-style routing:

```bash
./test-webflux-showcase.sh 8 5000 60 1000 http://${LB_IP}
```

## What to measure

Do not look only at throughput.

For this benchmark, compare:

### 1. `Requests/sec`
Useful, but not enough by itself.

### 2. Latency distribution
Look at:
- p50
- p95
- p99

### 3. Live thread count
Use:
- `/actuator/metrics/jvm.threads.live`

Expected pattern:
- MVC: increases quickly and hits limits sooner
- Virtual Threads: may support much larger concurrency, but live thread count can still rise substantially
- WebFlux: should keep thread count relatively low

### 4. Memory usage
Use:
- `/actuator/metrics/jvm.memory.used`

Expected pattern:
- MVC: memory pressure rises with blocked request load
- Virtual Threads: lower than MVC, but still not the same as non-blocking event-loop handling
- WebFlux: typically lowest for this specific wait-heavy scenario

### 5. Error rate / timeout rate
This is critical.

If one model reports higher throughput but also much higher failure rate, it is not actually winning.

## Expected result pattern

### `Traditional MVC`
Expected to degrade first because:
- request handling still depends on a bounded servlet thread pool
- blocked requests consume platform thread capacity

### `Virtual Threads`
Expected to do much better than MVC because:
- blocking waits are much cheaper on virtual threads than on platform threads
- concurrency can grow much further without exhausting the classic servlet worker model

### `WebFlux`
Expected to look strongest in:
- live thread count
- memory efficiency
- high-concurrency waiting workloads

It should also stand out in:
- long-lived reactive streams such as SSE
- workloads with many open idle or semi-idle client connections
- event-driven delivery where the server emits over time instead of computing synchronously per request

Why:
- `Mono.delay(...)` is non-blocking
- the server can schedule wake-up events without holding a blocked thread per request

## What this benchmark proves

If this test behaves as expected, it demonstrates a very specific and important point:

> `WebFlux` is most valuable when the workload is dominated by waiting that can be modeled non-blockingly.

That is different from saying `WebFlux` is always faster.

The right conclusion is narrower and more useful:

- `Traditional MVC` is still excellent for simple services and moderate concurrency
- `Virtual Threads` are excellent for blocking workloads that need higher concurrency with minimal rewrite
- `WebFlux` shines when the request path can be expressed as true non-blocking work

## Suggested article takeaway

If you include this scenario in your article, a good summary line is:

> The value of `WebFlux` becomes obvious when requests spend most of their lifetime waiting non-blockingly, not when a blocking workload is simply wrapped in a reactive shell.

And for streaming workloads, an equally useful summary is:

> `WebFlux` shines when the application needs to keep many connections open and push events over time with minimal thread overhead.
