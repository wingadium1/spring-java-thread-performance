# Hardware Limit Testing Guide

This guide explains how to push each Spring Boot implementation to hardware limits to understand their breaking points and performance characteristics under extreme load.

## Understanding the Enhanced Database Simulator

The database simulator now includes three types of resource consumption:

### 1. I/O Simulation (Thread Blocking)
- Simulates network/disk latency
- Uses `Thread.sleep()` to block threads
- Represents waiting for database, external APIs, file I/O

### 2. CPU Simulation (Computation)
- Simulates query processing, JSON parsing, data transformation
- Performs actual CPU work (hashing, string operations)
- Consumes real CPU cycles

### 3. Memory Simulation (Allocation)
- Simulates result set processing
- Allocates actual objects in heap
- Triggers GC pressure under load

## Workload Profiles

Choose a profile based on what you want to test:

### LIGHT (10-50ms I/O, minimal CPU/memory)
**Use for:** Baseline performance, connection overhead testing
```bash
--app.workload.profile=LIGHT
```

### MEDIUM (50-200ms I/O, minimal CPU/memory) - Default
**Use for:** Standard CRUD operations, typical REST API
```bash
--app.workload.profile=MEDIUM
```

### HEAVY (100-500ms I/O, minimal CPU/memory)
**Use for:** Slow database queries, external API calls with latency
```bash
--app.workload.profile=HEAVY
```

### IO_PLUS_CPU (50-200ms I/O + 10-50ms CPU)
**Use for:** Queries with result processing
```bash
--app.workload.profile=IO_PLUS_CPU
```

### IO_PLUS_MEMORY (50-200ms I/O + 1-5MB allocations)
**Use for:** Large result sets, report generation
```bash
--app.workload.profile=IO_PLUS_MEMORY
```

### REALISTIC_MIXED (50-200ms I/O + 20-100ms CPU + 512KB-2MB memory)
**Use for:** Real-world simulation with all three resource types
```bash
--app.workload.profile=REALISTIC_MIXED
```

### CPU_INTENSIVE (10-50ms I/O + 100-500ms CPU)
**Use for:** Data processing, calculations, transformations
```bash
--app.workload.profile=CPU_INTENSIVE
```

### EXTREME (200-1000ms I/O + 50-200ms CPU + 5-10MB memory)
**Use for:** Finding breaking points, stress testing
```bash
--app.workload.profile=EXTREME
```

## New API Endpoints

### CPU-Intensive Work
```bash
# Execute CPU work for specified milliseconds
curl http://localhost:8080/api/cpu/100
```

### Stress Test
```bash
# Combined I/O + CPU + memory load
curl "http://localhost:8080/api/stress?queries=5&cpuMs=100"
```

## Testing Scenarios for Hardware Limits

### Scenario 1: I/O-Bound Workload (High Concurrency)

**Goal:** Find thread pool exhaustion point for Traditional MVC

```bash
# Start Traditional MVC with HEAVY profile
cd spring-mvc-traditional
mvn spring-boot:run -Dspring-boot.run.arguments="--app.workload.profile=HEAVY"

# Test with increasing concurrency
wrk -t4 -c100 -d60s http://localhost:8080/api/query
wrk -t4 -c200 -d60s http://localhost:8080/api/query
wrk -t4 -c500 -d60s http://localhost:8080/api/query
wrk -t8 -c1000 -d60s http://localhost:8080/api/query
wrk -t8 -c2000 -d60s http://localhost:8080/api/query  # Should see degradation
```

**Expected Results:**
- Traditional MVC: Degrades at 200-400 concurrent (thread pool limit)
- Virtual Threads: Handles 1000+ concurrent connections easily
- WebFlux: Handles 2000+ concurrent connections

**Monitor:**
```bash
# Thread count
curl http://localhost:8080/actuator/metrics/jvm.threads.live

# Memory usage
curl http://localhost:8080/actuator/metrics/jvm.memory.used

# CPU usage (from system)
top -p $(pgrep -f spring-mvc-traditional)
```

### Scenario 2: CPU-Bound Workload

**Goal:** Measure CPU saturation and throughput limits

```bash
# Start with CPU_INTENSIVE profile
mvn spring-boot:run -Dspring-boot.run.arguments="--app.workload.profile=CPU_INTENSIVE"

# Test CPU endpoint
wrk -t8 -c100 -d60s http://localhost:8080/api/cpu/100
wrk -t8 -c200 -d60s http://localhost:8080/api/cpu/200
```

**Expected Results:**
- All approaches perform similarly (CPU-bound, not I/O-bound)
- Throughput limited by CPU cores
- Higher concurrency doesn't help much

### Scenario 3: Memory-Intensive Workload

**Goal:** Find memory limits and GC pressure points

```bash
# Start with IO_PLUS_MEMORY profile
mvn spring-boot:run -Dspring-boot.run.arguments="--app.workload.profile=IO_PLUS_MEMORY --java.opts=-Xmx2g"

# Heavy memory allocation test
wrk -t8 -c500 -d60s http://localhost:8080/api/query
```

**Monitor GC:**
```bash
# GC pauses
curl http://localhost:8080/actuator/metrics/jvm.gc.pause

# Memory pools
curl http://localhost:8080/actuator/metrics/jvm.memory.used?tag=area:heap
```

**Expected Results:**
- Traditional MVC: Higher memory due to many threads (each ~1MB stack)
- Virtual Threads: Lower memory (virtual thread stacks are smaller)
- WebFlux: Lowest memory (few threads, efficient queuing)

### Scenario 4: Realistic Mixed Workload

**Goal:** Test realistic application behavior

```bash
# Start with REALISTIC_MIXED profile
mvn spring-boot:run -Dspring-boot.run.arguments="--app.workload.profile=REALISTIC_MIXED"

# Stress test with mixed operations
wrk -t8 -c500 -d120s "http://localhost:8080/api/stress?queries=5&cpuMs=100"
```

**Expected Results:**
- Best representation of real production load
- Shows combined effects of I/O, CPU, and memory
- Virtual Threads show clear advantage over Traditional MVC
- WebFlux performs best if properly tuned

### Scenario 5: Extreme Load (Finding Breaking Points)

**Goal:** Find absolute limits

```bash
# Start with EXTREME profile and maxed configuration
# Traditional MVC
mvn spring-boot:run -Dspring-boot.run.arguments="--spring.profiles.active=extreme"

# Gradually increase load until failure
wrk -t8 -c500 -d60s http://localhost:8080/api/query
wrk -t8 -c1000 -d60s http://localhost:8080/api/query
wrk -t8 -c2000 -d60s http://localhost:8080/api/query
wrk -t16 -c5000 -d60s http://localhost:8080/api/query  # Should fail for MVC

# Monitor for errors
curl http://localhost:8080/actuator/health
```

**Signs of Breaking:**
- Connection refused errors (thread pool exhausted)
- HTTP 503 Service Unavailable
- Very high latency (>10s)
- Out of Memory errors
- Application crash

## Container Resource Limits

Test with Docker resource constraints to simulate production:

```bash
# Build Docker image
mvn clean package jib:dockerBuild

# Run with CPU limit (2 cores)
docker run -d -p 8080:8080 --cpus="2" --name mvc-limited \
  -e JAVA_TOOL_OPTIONS="-Xmx1g" \
  -e APP_WORKLOAD_PROFILE=REALISTIC_MIXED \
  spring-performance/spring-mvc-traditional

# Test under CPU constraint
wrk -t4 -c200 -d60s http://localhost:8080/api/stress

# Run with memory limit (1GB)
docker run -d -p 8080:8080 --memory="1g" --name mvc-limited \
  -e JAVA_TOOL_OPTIONS="-Xmx768m" \
  -e APP_WORKLOAD_PROFILE=IO_PLUS_MEMORY \
  spring-performance/spring-mvc-traditional

# Test under memory constraint
wrk -t8 -c500 -d60s http://localhost:8080/api/query
```

## Comparison Matrix

Run the same test across all three implementations:

```bash
# Script to test all three
for port in 8080 8081 8082; do
  echo "Testing port $port..."
  wrk -t8 -c500 -d60s http://localhost:$port/api/stress | \
    grep -E "Requests/sec|Latency"
  echo "---"
done
```

## Key Metrics to Monitor

### 1. Throughput
```bash
# From wrk output
Requests/sec: XXX
```

### 2. Latency Distribution
```bash
# From wrk output
Latency    50%    95%    99%
```

### 3. Thread Count
```bash
curl http://localhost:8080/actuator/metrics/jvm.threads.live | jq .
```

### 4. Memory Usage
```bash
curl http://localhost:8080/actuator/metrics/jvm.memory.used | jq .
```

### 5. CPU Usage
```bash
# System level
docker stats <container-name>

# Or
top -p $(pgrep -f spring-mvc)
```

### 6. GC Activity
```bash
curl http://localhost:8080/actuator/metrics/jvm.gc.pause | jq .
```

## Expected Breaking Points

### Traditional Spring MVC
- **Concurrency Limit:** ~200-400 concurrent requests (thread pool)
- **Memory:** ~200-800 MB (depends on thread count)
- **CPU:** N/A (not CPU-limited until threads saturate)
- **Symptoms:** Connection refused, 503 errors, high latency

### Virtual Threads
- **Concurrency Limit:** 10,000+ concurrent requests
- **Memory:** ~100-300 MB (virtual threads are lightweight)
- **CPU:** Saturates all cores before thread limit
- **Symptoms:** CPU saturation, slower response times under load

### WebFlux
- **Concurrency Limit:** 10,000+ concurrent requests
- **Memory:** ~50-200 MB (event loop model)
- **CPU:** Most efficient CPU usage
- **Symptoms:** Bounded elastic pool saturation if too many blocking ops

## Tuning Recommendations

### Traditional MVC
```properties
# Increase thread pool for higher concurrency
server.tomcat.threads.max=400
server.tomcat.max-connections=20000

# Optimize timeouts
server.tomcat.connection-timeout=30s

# JVM tuning
-Xmx2g -Xms2g -XX:+UseG1GC -XX:MaxGCPauseMillis=200
```

### Virtual Threads
```properties
# Virtual threads handle concurrency, focus on connections
server.tomcat.max-connections=50000

# Lower thread pool (virtual threads managed by JVM)
server.tomcat.threads.max=200

# JVM tuning (less memory needed)
-Xmx1g -Xms1g -XX:+UseG1GC
```

### WebFlux
```properties
# Tune event loop workers (usually = CPU cores)
reactor.netty.ioWorkerCount=8

# Tune bounded elastic pool for blocking operations
# Default: 10 * CPU cores
spring.reactor.schedulers.boundedElastic.maxThreads=80

# JVM tuning (minimal memory)
-Xmx512m -Xms512m -XX:+UseG1GC
```

## Container-Specific Considerations

When running in containers (Kubernetes, Docker):

1. **Set proper resource requests and limits**
```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "2000m"
```

2. **Configure JVM heap based on container memory**
```bash
# Rule of thumb: heap = 75% of container memory
-Xmx1536m  # for 2GB container
```

3. **Use readiness/liveness probes**
```yaml
livenessProbe:
  httpGet:
    path: /actuator/health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
```

4. **Set appropriate autoscaling triggers**
```yaml
# Scale on CPU usage
targetCPUUtilizationPercentage: 70

# Or custom metrics (latency, queue depth)
```

## Conclusion

The goal is to understand:
1. **Where each approach breaks** (concurrency limits, memory limits, CPU saturation)
2. **Resource efficiency** (requests per MB, requests per CPU core)
3. **Operational characteristics** (startup time, memory stability, GC behavior)
4. **Cost implications** (how many instances needed for target load)

Use these tests to make informed decisions about which approach suits your specific use case and constraints.
