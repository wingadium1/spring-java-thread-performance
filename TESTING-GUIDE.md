# Performance Testing and Comparison Guide

## Overview

This guide provides detailed information on how to conduct performance testing and interpret results for the three different Spring Boot threading models.

## Test Scenarios

### Scenario 1: Low Concurrency (100 concurrent users)
**Goal**: Establish baseline performance under normal load

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

**Expected Results**:
- All three approaches should perform similarly
- Traditional MVC may have a slight edge due to simplicity
- Latency: ~50-200ms (simulated DB delay)
- Throughput: ~500-800 req/sec

### Scenario 2: Medium Concurrency (500 concurrent users)
**Goal**: Test behavior as load increases

```bash
wrk -t8 -c500 -d60s http://localhost:8080/api/query
wrk -t8 -c500 -d60s http://localhost:8081/api/query
wrk -t8 -c500 -d60s http://localhost:8082/api/query
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

```bash
wrk -t8 -c1000 -d60s http://localhost:8080/api/query
wrk -t8 -c1000 -d60s http://localhost:8081/api/query
wrk -t8 -c1000 -d60s http://localhost:8082/api/query
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

```bash
wrk -t8 -c500 -d60s http://localhost:8080/api/query/500
wrk -t8 -c500 -d60s http://localhost:8081/api/query/500
wrk -t8 -c500 -d60s http://localhost:8082/api/query/500
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

# Or via actuator
curl http://localhost:8080/actuator/metrics/jvm.memory.used
```

**Expected Memory Usage**:
- Traditional MVC: ~200MB heap (200 threads × 1MB stack each)
- Virtual Threads: ~50-100MB heap (virtual threads are lightweight)
- WebFlux: ~50-80MB heap (few threads, many tasks)

#### Thread Count
```bash
# Via actuator
curl http://localhost:8080/actuator/metrics/jvm.threads.live

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

## Additional Resources

- [Spring Boot Performance Tuning](https://spring.io/blog/2020/12/03/spring-boot-performance-tuning)
- [Java Virtual Threads JEP 444](https://openjdk.org/jeps/444)
- [Project Reactor Documentation](https://projectreactor.io/docs)
- [wrk Documentation](https://github.com/wg/wrk)
- [Apache Bench Guide](https://httpd.apache.org/docs/2.4/programs/ab.html)
