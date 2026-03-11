# Performance Testing and Comparison Guide

## Overview

This guide provides detailed information on how to conduct performance testing and interpret results for the three different Spring Boot threading models.

## Deployment Modes

### Local Deployment
When running applications locally (Docker Compose or standalone), access services via direct ports:
- Traditional MVC: `http://localhost:8080`
- Virtual Threads: `http://localhost:8081`
- WebFlux: `http://localhost:8082`

### Kubernetes Deployment
When deployed on Kubernetes with Ingress, access services via path-based routing:
- Traditional MVC: `http://${LB_IP}/mvc`
- Virtual Threads: `http://${LB_IP}/virtual`
- WebFlux: `http://${LB_IP}/webflux`

Get the LoadBalancer IP:
```bash
LB_IP=$(kubectl get ingress spring-performance-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

## Test Scenarios

### Scenario 1: Low Concurrency (100 concurrent users)
**Goal**: Establish baseline performance under normal load

**For Local Deployment:**
```bash
# Using wrk
wrk -t4 -c100 -d30s http://localhost:8080/api/query
wrk -t4 -c100 -d30s http://localhost:8081/api/query
wrk -t4 -c100 -d30s http://localhost:8082/api/query

# Using Apache Bench
ab -n 10000 -c 100 http://localhost:8080/api/query
ab -n 10000 -c 100 http://localhost:8081/api/query
ab -n 10000 -c 100 http://localhost:8082/api/query
```

**For Kubernetes Deployment:**
```bash
# Using wrk
wrk -t4 -c100 -d30s http://${LB_IP}/mvc/api/query
wrk -t4 -c100 -d30s http://${LB_IP}/virtual/api/query
wrk -t4 -c100 -d30s http://${LB_IP}/webflux/api/query

# Using Apache Bench
ab -n 10000 -c 100 http://${LB_IP}/mvc/api/query
ab -n 10000 -c 100 http://${LB_IP}/virtual/api/query
ab -n 10000 -c 100 http://${LB_IP}/webflux/api/query
```

**Expected Results**:
- All three approaches should perform similarly
- Traditional MVC may have a slight edge due to simplicity
- Latency: ~50-200ms (simulated DB delay)
- Throughput: ~500-800 req/sec

### Scenario 2: Medium Concurrency (500 concurrent users)
**Goal**: Test behavior as load increases

**For Local Deployment:**
```bash
wrk -t8 -c500 -d60s http://localhost:8080/api/query
wrk -t8 -c500 -d60s http://localhost:8081/api/query
wrk -t8 -c500 -d60s http://localhost:8082/api/query
```

**For Kubernetes Deployment:**
```bash
wrk -t8 -c500 -d60s http://${LB_IP}/mvc/api/query
wrk -t8 -c500 -d60s http://${LB_IP}/virtual/api/query
wrk -t8 -c500 -d60s http://${LB_IP}/webflux/api/query
```

**Expected Results**:
- **Traditional MVC**: May start showing thread pool saturation
  - Latency increases as threads are exhausted
  - Throughput plateaus around 200 threads
  
- **Virtual Threads**: Should maintain performance
  - Minimal latency increase
  - High throughput maintained
  
- **WebFlux**: Should perform well
  - Low latency due to non-blocking I/O
  - High throughput with event loop

### Scenario 3: High Concurrency (1000+ concurrent users)
**Goal**: Test maximum capacity

**For Local Deployment:**
```bash
wrk -t8 -c1000 -d60s http://localhost:8080/api/query
wrk -t8 -c1000 -d60s http://localhost:8081/api/query
wrk -t8 -c1000 -d60s http://localhost:8082/api/query
```

**For Kubernetes Deployment:**
```bash
wrk -t8 -c1000 -d60s http://${LB_IP}/mvc/api/query
wrk -t8 -c1000 -d60s http://${LB_IP}/virtual/api/query
wrk -t8 -c1000 -d60s http://${LB_IP}/webflux/api/query
```

**Expected Results**:
- **Traditional MVC**: 
  - Significant performance degradation
  - High latency (>1000ms)
  - Possible connection timeouts
  - Thread pool exhausted (max 200 threads by default)
  
- **Virtual Threads**:
  - Excellent performance
  - Can handle millions of virtual threads
  - Latency remains reasonable
  - High throughput maintained
  
- **WebFlux**:
  - Best performance if properly tuned
  - Low latency
  - Highest throughput
  - Efficient resource utilization

### Scenario 4: Long-Running Operations (500ms delay)
**Goal**: Test with longer blocking operations

**For Local Deployment:**
```bash
wrk -t8 -c500 -d60s http://localhost:8080/api/query/500
wrk -t8 -c500 -d60s http://localhost:8081/api/query/500
wrk -t8 -c500 -d60s http://localhost:8082/api/query/500
```

**For Kubernetes Deployment:**
```bash
wrk -t8 -c500 -d60s http://${LB_IP}/mvc/api/query/500
wrk -t8 -c500 -d60s http://${LB_IP}/virtual/api/query/500
wrk -t8 -c500 -d60s http://${LB_IP}/webflux/api/query/500
```

**Expected Results**:
- **Traditional MVC**: Severe degradation
  - Very high latency
  - Low throughput (< 50 req/sec)
  
- **Virtual Threads**: Good performance
  - Can handle many concurrent long-running operations
  - Throughput: ~500-800 req/sec
  
- **WebFlux**: Best performance
  - Efficient handling of async operations
  - Throughput: ~1000+ req/sec

### Scenario 5: True Non-Blocking Wait (`/api/wait/{delayMs}`)
**Goal**: Highlight the value of `WebFlux` when requests spend most of their lifetime waiting non-blockingly.

This scenario is different from `/api/query/{delay}`:
- MVC and Virtual Threads use blocking `Thread.sleep(...)`
- WebFlux uses `Mono.delay(...)`, which does not block a worker thread while waiting

**For Local Deployment:**
```bash
wrk -t8 -c1000 -d60s http://localhost:8080/api/wait/1000
wrk -t8 -c1000 -d60s http://localhost:8081/api/wait/1000
wrk -t8 -c1000 -d60s http://localhost:8082/api/wait/1000
```

**For Kubernetes Deployment:**
```bash
wrk -t8 -c1000 -d60s http://${LB_IP}/mvc/api/wait/1000
wrk -t8 -c1000 -d60s http://${LB_IP}/virtual/api/wait/1000
wrk -t8 -c1000 -d60s http://${LB_IP}/webflux/api/wait/1000
```

**What to compare**:
- throughput
- p95 / p99 latency
- live thread count
- memory usage
- timeout rate

**Expected Results**:
- **Traditional MVC**:
  - hits servlet thread limits first
  - latency rises quickly under large waiting concurrency
  - error or timeout risk increases once worker threads are exhausted

- **Virtual Threads**:
  - handles waiting concurrency much better than MVC
  - preserves blocking code style
  - thread usage can still grow with request volume, but much more economically than platform threads

- **WebFlux**:
  - should show its clearest advantage here
  - uses very few worker threads even with many waiting requests
  - should have the best thread efficiency and often the best memory efficiency in this scenario

For a ready-to-run version of this benchmark, see [WEBFLUX-SHOWCASE-TEST.md](WEBFLUX-SHOWCASE-TEST.md) and [test-webflux-showcase.sh](test-webflux-showcase.sh).

### Scenario 6: Reactive Streaming with SSE (`/api/sse/{events}`)
**Goal**: Highlight where `WebFlux` shines most clearly: long-lived streams and many concurrent waiting connections.

This scenario keeps a connection open and emits events at a fixed interval.

- MVC uses `SseEmitter` and keeps a request open with platform-thread-oriented processing
- Virtual Threads also keeps a blocking-style request lifecycle, but with cheaper threads
- WebFlux emits a reactive stream over time using `Flux.interval(...)`

**Functional test:**
```bash
curl -N http://localhost:8080/api/sse/5?intervalMs=1000
curl -N http://localhost:8081/api/sse/5?intervalMs=1000
curl -N http://localhost:8082/api/sse/5?intervalMs=1000
```

**What to compare under load:**
- number of concurrent open streams
- live thread count
- memory usage
- stability over long-lived connections

**Expected Results**:
- **Traditional MVC**:
  - reaches thread-related overhead first on many concurrent streams
  - good for small and moderate SSE usage, but less ideal for very large waiting fan-out

- **Virtual Threads**:
  - better than MVC for many open streaming connections
  - easier migration path when the application is still written in blocking style

- **WebFlux**:
  - should stand out most strongly here
  - long-lived streams map naturally to reactive pipelines
  - best fit when the application has many concurrent waiting clients and event-style delivery

For result reporting, use [summarize-wrk-results.sh](summarize-wrk-results.sh) on any `wrk` result directory to build a Markdown or CSV summary automatically.

## Key Metrics to Monitor

### 1. Throughput (Requests/sec)
- How many requests per second each implementation can handle
- Higher is better

### 2. Latency
- **p50 (median)**: Half of requests complete faster than this
- **p95**: 95% of requests complete faster than this
- **p99**: 99% of requests complete faster than this
- Lower is better

### 3. Resource Usage

#### CPU Usage
```bash
# Monitor CPU while tests run
top -b -n 1 | grep java

# Or with docker
docker stats
```

**Expected CPU Usage**:
- Traditional MVC: High CPU during context switching
- Virtual Threads: Moderate CPU, efficient thread management
- WebFlux: Low CPU, event loop efficiency

#### Memory Usage
```bash
# Check JVM heap usage
jmap -heap <pid>

# Or via actuator (local deployment)
curl http://localhost:8080/actuator/metrics/jvm.memory.used

# Or via actuator (Kubernetes deployment)
curl http://${LB_IP}/mvc/actuator/metrics/jvm.memory.used
```

**Expected Memory Usage**:
- Traditional MVC: ~200MB heap (200 threads × 1MB stack each)
- Virtual Threads: ~50-100MB heap (virtual threads are lightweight)
- WebFlux: ~50-80MB heap (few threads, many tasks)

#### Thread Count
```bash
# Via actuator (local deployment)
curl http://localhost:8080/actuator/metrics/jvm.threads.live

# Via actuator (Kubernetes deployment)
curl http://${LB_IP}/mvc/actuator/metrics/jvm.threads.live

# Via jstack
jstack <pid> | grep "Thread" | wc -l
```

**Expected Thread Count**:
- Traditional MVC: ~200-250 threads (limited by thread pool)
- Virtual Threads: Thousands to millions (depends on concurrent requests)
- WebFlux: ~20-50 threads (event loop + bounded elastic)

### 4. Error Rate
- Should be 0% under normal load
- Traditional MVC may show errors (503) under high load due to thread exhaustion
- Virtual Threads and WebFlux should handle high load without errors

## Testing Tools Comparison

### Apache Bench (ab)
**Pros**:
- Simple to use
- Available on most systems
- Good for basic tests

**Cons**:
- Limited to single URL
- No request scripting
- Basic metrics

**Best for**: Quick tests, baseline performance

### wrk
**Pros**:
- High performance (can generate more load)
- Lua scripting support
- Detailed latency distribution
- Better concurrency handling

**Cons**:
- Requires installation
- Slightly more complex

**Best for**: Realistic load testing, detailed analysis

### JMeter
**Pros**:
- GUI interface
- Complex scenarios
- Detailed reports
- Can test multiple endpoints

**Cons**:
- Heavy resource usage
- Steeper learning curve

**Best for**: Complex test scenarios, comprehensive testing

### Gatling
**Pros**:
- Scala-based DSL
- Excellent reports
- Good for realistic load patterns
- CI/CD friendly

**Cons**:
- Requires JVM
- Learning curve for DSL

**Best for**: Professional load testing, CI/CD integration

## Interpreting Results

### Example wrk Output
```
Running 30s test @ http://localhost:8080/api/query
  4 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   125.23ms   25.14ms   250.00ms   89.56%
    Req/Sec   201.50     15.23     250.00     92.00%
  24120 requests in 30.05s, 5.12MB read
Requests/sec:    802.66
Transfer/sec:    174.50KB
```

**Key Observations**:
- **Latency Avg**: 125ms is within expected range (50-200ms simulated delay)
- **Latency Max**: 250ms shows some variance
- **Requests/sec**: 802 is good throughput for this scenario
- **No errors**: System handling load well

### Red Flags to Watch For

1. **Increasing Latency Over Time**: Indicates resource exhaustion or memory leaks
2. **Socket Errors**: Connection refused, timeouts (thread pool exhausted)
3. **High CPU with Low Throughput**: Context switching overhead (Traditional MVC)
4. **Out of Memory Errors**: Insufficient heap or too many threads

## Performance Comparison Summary

| Metric | Traditional MVC | Virtual Threads | WebFlux |
|--------|----------------|-----------------|---------|
| **Max Concurrency** | Low (~200) | Very High (millions) | Very High (thousands) |
| **Throughput (low load)** | Good | Good | Good |
| **Throughput (high load)** | Poor | Excellent | Excellent |
| **Latency (low load)** | Good | Good | Good |
| **Latency (high load)** | Poor | Good | Excellent |
| **Memory Usage** | High | Low | Low |
| **CPU Usage** | High | Medium | Low |
| **Complexity** | Low | Low | High |
| **Learning Curve** | Easy | Easy | Steep |
| **Best For** | Simple apps, low concurrency | High concurrency, blocking I/O | High concurrency, non-blocking I/O |

## Recommendations

### Use Traditional MVC when:
- Low to medium concurrency (< 200 concurrent requests)
- Simple CRUD applications
- Team is familiar with blocking I/O
- Quick prototyping

### Use Virtual Threads when:
- High concurrency with blocking I/O (database, external APIs)
- Easier migration from Traditional MVC
- Need better performance without code complexity
- Java 21+ is available

### Use WebFlux when:
- Very high concurrency required
- Team has reactive programming expertise
- Building microservices with async communication
- Non-blocking I/O can be utilized throughout

## Load Testing Checklist

- [ ] Test with realistic data payload sizes
- [ ] Test all critical endpoints
- [ ] Gradually increase load (ramp-up testing)
- [ ] Test sustained load (soak testing)
- [ ] Test spike scenarios
- [ ] Monitor all system resources (CPU, memory, network, disk)
- [ ] Check application logs for errors
- [ ] Verify database connection pool settings
- [ ] Test with production-like data volume
- [ ] Document all test parameters and results
- [ ] Compare results across implementations
- [ ] Identify bottlenecks and optimization opportunities

## Recommended Full Regression Run

To rerun the main comparison scenarios in one pass, use [load-test-wrk.sh](load-test-wrk.sh).

It now executes:
- standard blocking query
- long blocking query (`500ms`)
- CPU-intensive endpoint
- mixed stress endpoint
- non-blocking wait showcase

Example:

```bash
./load-test-wrk.sh 8 200 60 http://${LB_IP}
```

Useful overrides:

```bash
CPU_DURATION_MS=100 \
STRESS_QUERIES=5 \
STRESS_CPU_MS=100 \
WAIT_DELAY_MS=1000 \
SETTLE_SECONDS=5 \
./load-test-wrk.sh 8 200 60 http://${LB_IP}
```

After the run, summarize results with:

```bash
./summarize-wrk-results.sh <results_dir> markdown
```

## Additional Resources

- [Spring Boot Performance Tuning](https://spring.io/blog/2020/12/03/spring-boot-performance-tuning)
- [Java Virtual Threads JEP 444](https://openjdk.org/jeps/444)
- [Project Reactor Documentation](https://projectreactor.io/docs)
- [wrk Documentation](https://github.com/wg/wrk)
- [Apache Bench Guide](https://httpd.apache.org/docs/2.4/programs/ab.html)
