# Accurate Comparison Guide

This guide redesigns the benchmark so the comparison between `Traditional MVC`, `Virtual Threads`, and `WebFlux` is more accurate and easier to explain.

## Why the previous test was noisy

The earlier run mixed three different effects:

1. **Architecture differences**
2. **Kubernetes pod scaling behavior**
3. **Cluster resource contention**

When all three applications are running on the same cluster at the same time, they compete for the same CPU and memory. That makes the comparison less trustworthy because one implementation can slow another down.

There is also an architectural mismatch in the current code:

- `Traditional MVC` and `Virtual Threads` execute blocking work directly.
- `WebFlux` wraps the same blocking work using `boundedElastic`.

So a blocking benchmark is a fair comparison between `MVC` and `Virtual Threads`, but only a partial comparison for `WebFlux`.

## Redesigned benchmark model

Use **three separate benchmark phases**.

### Phase 1: Architecture baseline

Goal: compare request-handling models with the least Kubernetes noise.

Rules:
- disable HPA
- run **one application at a time**
- scale the target application to **1 pod**
- scale the other two applications to **0 pods**
- keep the same CPU and memory allocation for every application
- use the same workload profile for every run
- warm up before measuring
- repeat each test at least 3 times

This phase answers:
- how does each model behave without cross-service interference?

### Phase 2: Fixed horizontal scaling

Goal: compare how each implementation scales horizontally.

Rules:
- still keep HPA disabled
- test one application at a time
- run the target application at **1, 2, and 4 pods**
- keep **per-pod** CPU and memory identical
- keep concurrency steps identical for every implementation

This phase answers:
- how much extra throughput do you gain from more replicas?
- how does latency change as replicas increase?

### Phase 3: Autoscaling behavior

Goal: test operational elasticity, not architecture purity.

Rules:
- enable HPA
- start from 2 replicas
- run longer tests to give the autoscaler time to react
- treat this as a separate benchmark category

This phase answers:
- how well does the deployment react under real cluster pressure?

Do **not** mix autoscaling results into the architecture baseline.

## Recommended pod scale levels

For the most accurate comparison, use this scale matrix.

| Phase | Replicas | HPA | Purpose |
|---|---:|---|---|
| Baseline | 1 | Off | Pure per-request model comparison |
| Scale step 1 | 2 | Off | Small horizontal scale comparison |
| Scale step 2 | 4 | Off | Larger horizontal scale comparison |
| Elasticity | 2 to 10 | On | Autoscaling behavior only |

## Recommended resource model

For controlled benchmarks, keep the pod shape the same for all apps.

### Recommended benchmark pod shape

- `cpu request = 2000m`
- `cpu limit = 2000m`
- `memory request = 2Gi`
- `memory limit = 2Gi`

Why:
- same per-pod resource envelope
- predictable scheduling
- `Guaranteed` QoS when requests equal limits
- less noise from bursty CPU sharing

If your cluster is smaller, reduce the numbers, but keep them identical across all three apps.

## Recommended workload matrix

Use different concurrency ladders for different endpoint types.

### Blocking query endpoints

Use for:
- `/api/query`
- `/api/query/500`

Recommended concurrencies per test:
- `50`
- `100`
- `200`
- `400`

These scenarios are the cleanest comparison for `MVC` vs `Virtual Threads`.

### CPU-intensive endpoint

Use for:
- `/api/cpu/100`

Recommended concurrencies per test:
- `16`
- `32`
- `64`
- `128`

Reason:
- CPU tests saturate quickly
- very high concurrency adds queueing noise and timeouts
- lower concurrency gives more meaningful throughput and latency numbers

### Mixed stress endpoint

Use for:
- `/api/stress?queries=5&cpuMs=100`

Recommended concurrencies per test:
- `25`
- `50`
- `100`
- `200`

Reason:
- mixed I/O + CPU workloads fail earlier
- moderate concurrency is easier to interpret than overloaded failure storms

## Recommended timing

For each case:
- warmup: `30s`
- measured run: `120s`
- repeats: `3`

Then report:
- median `Requests/sec`
- median `p95 latency`
- median `p99 latency`
- timeout count
- non-2xx count
- success rate

## Metrics that must be collected

For every measured run, capture:

### Load tool output
- throughput
- avg latency
- p50/p95/p99 latency
- timeout count
- non-2xx count

### Pod metrics
- `kubectl top pods`
- `kubectl top nodes`

### Application metrics
- `/actuator/metrics/jvm.threads.live`
- `/actuator/metrics/jvm.memory.used`
- `/actuator/metrics/jvm.gc.pause`
- `/actuator/metrics/system.cpu.usage`

## How to interpret WebFlux fairly

With the current implementation, `WebFlux` is handling blocking work through `boundedElastic`, not true non-blocking I/O.

That means:
- blocking endpoint results are still useful
- but they do **not** prove the full value of WebFlux

For a truly fair `WebFlux` benchmark, add a separate **reactive track** with a non-blocking endpoint, such as:
- Reactor `Mono.delay(...)`
- R2DBC instead of JDBC-style blocking access
- a non-blocking HTTP client for upstream calls

### Best practice

Publish two result groups:

1. **Blocking comparison**
   - MVC
   - Virtual Threads
   - WebFlux-with-blocking-offload

2. **Reactive comparison**
   - WebFlux with true non-blocking I/O
   - optionally compare against async MVC variants if added later

## Isolation rules for trustworthy numbers

For the most accurate numbers:
- benchmark one application at a time
- scale non-target applications to zero
- use the same node pool for every run
- do not run monitoring-heavy jobs during the benchmark window
- do not mix baseline and autoscaling tests
- do not compare runs with different workload profiles
- reject runs with large timeout spikes

## New benchmark script

Use [benchmark-k8s-accurate.sh](benchmark-k8s-accurate.sh) for controlled Kubernetes benchmarking.

What it does:
- warns if HPA is present
- isolates one application at a time
- scales the target deployment to `1`, `2`, and `4` replicas
- warms up before every run
- runs 3 repeated measurements
- saves `wrk --latency` output
- captures `kubectl top` snapshots and key actuator metrics

Example:

```bash
chmod +x benchmark-k8s-accurate.sh
./benchmark-k8s-accurate.sh http://<LB-IP>
```

Optional environment overrides:

```bash
NAMESPACE=default \
THREADS=8 \
WARMUP=30 \
DURATION=120 \
RUNS=3 \
REPLICAS_LIST="1 2 4" \
./benchmark-k8s-accurate.sh http://<LB-IP>
```

## Suggested Kubernetes benchmark settings

Before running the benchmark:

```bash
kubectl delete -f deployment/kubernetes/hpa.yaml
kubectl apply -f deployment/kubernetes/spring-mvc-traditional.yaml
kubectl apply -f deployment/kubernetes/spring-virtual-threads.yaml
kubectl apply -f deployment/kubernetes/spring-webflux.yaml
kubectl apply -f deployment/kubernetes/ingress.yaml
```

If you want completely controlled resource allocation, edit each deployment manifest so all three use the same pod shape during the benchmark.

## Final recommendation

For the most accurate comparison:

1. use **1 pod** first for architecture baseline
2. test **2 pods** and **4 pods** as separate fixed-scale phases
3. keep **HPA off** during those comparison runs
4. benchmark **one application at a time**
5. compare `WebFlux` separately for true reactive workloads

That design will give you results that are easier to trust and easier to explain in an article or report.
