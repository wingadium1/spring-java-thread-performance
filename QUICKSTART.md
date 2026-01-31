# Quick Start Guide

Get started with the Spring Boot Performance Comparison project in 5 minutes!

## Prerequisites

- Java 21 (required for Virtual Threads)
- Maven 3.6+
- Docker and Docker Compose (optional, for containerized deployment)

## Quick Start (Local Development)

### 1. Build the Project

```bash
# Clone the repository
git clone https://github.com/wingadium1/spring-java-thread-performance.git
cd spring-java-thread-performance

# Build all modules
mvn clean package
```

### 2. Run Applications

Open 3 terminal windows and run:

**Terminal 1 - Traditional MVC:**
```bash
cd spring-mvc-traditional
mvn spring-boot:run
# Or with a specific workload profile:
# mvn spring-boot:run -Dspring-boot.run.arguments="--app.workload.profile=REALISTIC_MIXED"
```

**Terminal 2 - Virtual Threads:**
```bash
cd spring-virtual-threads
mvn spring-boot:run
# Or with CPU-intensive workload:
# mvn spring-boot:run -Dspring-boot.run.arguments="--app.workload.profile=CPU_INTENSIVE"
```

**Terminal 3 - WebFlux:**
```bash
cd spring-webflux
mvn spring-boot:run
# Or with extreme load testing:
# mvn spring-boot:run -Dspring-boot.run.arguments="--app.workload.profile=EXTREME"
```

### 3. Test the Applications

Open a new terminal and test each application:

```bash
# Traditional MVC (port 8080)
curl http://localhost:8080/api/info
curl http://localhost:8080/api/query

# Virtual Threads (port 8081)
curl http://localhost:8081/api/info
curl http://localhost:8081/api/query

# WebFlux (port 8082)
curl http://localhost:8082/api/info
curl http://localhost:8082/api/query
```

### 4. Test Enhanced Features

```bash
# CPU-intensive work
curl http://localhost:8080/api/cpu/100

# Stress test (combined I/O + CPU + memory)
curl "http://localhost:8080/api/stress?queries=5&cpuMs=100"

# Multiple queries
curl http://localhost:8080/api/multiple/3

# Run demonstration script
./demo-profiles.sh 8080
```

## Quick Start (Docker)

### 1. Build and Start

```bash
# Build Docker images
./build.sh

# Start all services
./start.sh
```

### 2. Access Services

- Traditional MVC: http://localhost:8080/api/info
- Virtual Threads: http://localhost:8081/api/info
- WebFlux: http://localhost:8082/api/info
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin/admin)

### 3. Run Load Tests

```bash
# Quick test with Apache Bench
./test-performance.sh 1000 50

# Advanced test with wrk
./load-test-wrk.sh 4 100 30
```

## What to Observe

### Traditional MVC
- Thread name: `http-nio-8080-exec-*`
- Thread type: `Platform`
- Good for low concurrency

### Virtual Threads
- Thread name: Empty or virtual thread identifier
- Thread type: `Virtual`
- Excellent for high concurrency with blocking I/O

### WebFlux
- Thread name: `reactor-http-*` or `boundedElastic-*`
- Thread type: `Platform` (but uses event loop)
- Best for high concurrency with non-blocking I/O

## Performance Testing

### Low Load Test
```bash
# 100 concurrent users, 1000 requests
ab -n 1000 -c 100 http://localhost:8080/api/query
ab -n 1000 -c 100 http://localhost:8081/api/query
ab -n 1000 -c 100 http://localhost:8082/api/query
```

Expected: All perform similarly (~500-800 req/sec)

### High Load Test
```bash
# 500 concurrent users, 60 seconds
wrk -t8 -c500 -d60s http://localhost:8080/api/query
wrk -t8 -c500 -d60s http://localhost:8081/api/query
wrk -t8 -c500 -d60s http://localhost:8082/api/query
```

Expected:
- Traditional MVC: Struggles (~100-200 req/sec)
- Virtual Threads: Excellent (~500-800 req/sec)
- WebFlux: Best (~800-1200 req/sec)

## Monitoring

### Check Metrics
```bash
# Thread count
curl http://localhost:8080/actuator/metrics/jvm.threads.live
curl http://localhost:8081/actuator/metrics/jvm.threads.live
curl http://localhost:8082/actuator/metrics/jvm.threads.live

# Memory usage
curl http://localhost:8080/actuator/metrics/jvm.memory.used
curl http://localhost:8081/actuator/metrics/jvm.memory.used
curl http://localhost:8082/actuator/metrics/jvm.memory.used
```

### View in Grafana
1. Open http://localhost:3000
2. Login with admin/admin
3. Create dashboard
4. Add Prometheus queries
5. Compare metrics across implementations

## Cleanup

### Local Development
Press Ctrl+C in each terminal to stop the applications

### Docker
```bash
docker-compose down
```

## Next Steps

- Read [TESTING-GUIDE.md](TESTING-GUIDE.md) for comprehensive testing strategies
- Read [HARDWARE-LIMITS-GUIDE.md](HARDWARE-LIMITS-GUIDE.md) for pushing systems to limits
- Read [README.md](README.md) for detailed documentation
- Check [deployment/](deployment/) for production deployment guides
- Explore the code to understand implementation differences

## Workload Profiles

Test different scenarios by setting the workload profile:

```bash
# Light load (baseline)
mvn spring-boot:run -Dspring-boot.run.arguments="--app.workload.profile=LIGHT"

# Realistic mixed (I/O + CPU + memory)
mvn spring-boot:run -Dspring-boot.run.arguments="--app.workload.profile=REALISTIC_MIXED"

# CPU-intensive (data processing)
mvn spring-boot:run -Dspring-boot.run.arguments="--app.workload.profile=CPU_INTENSIVE"

# Extreme load (stress testing)
mvn spring-boot:run -Dspring-boot.run.arguments="--app.workload.profile=EXTREME"
```

See [HARDWARE-LIMITS-GUIDE.md](HARDWARE-LIMITS-GUIDE.md) for details on all profiles.

## Common Issues

### Port Already in Use
Kill the process using the port:
```bash
lsof -ti:8080 | xargs kill -9
lsof -ti:8081 | xargs kill -9
lsof -ti:8082 | xargs kill -9
```

### Java Version
Ensure you're using Java 21:
```bash
java -version
# Should show: openjdk version "21.x.x"
```

If not, set JAVA_HOME:
```bash
export JAVA_HOME=/path/to/jdk-21
export PATH=$JAVA_HOME/bin:$PATH
```

### Docker Build Fails
Ensure Docker daemon is running:
```bash
docker info
```

## Support

For issues or questions:
1. Check the comprehensive [README.md](README.md)
2. Review the [TESTING-GUIDE.md](TESTING-GUIDE.md)
3. Open an issue on GitHub
