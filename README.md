# Spring Boot Thread Performance Comparison

[![CI](https://github.com/wingadium1/spring-java-thread-performance/actions/workflows/ci.yml/badge.svg)](https://github.com/wingadium1/spring-java-thread-performance/actions/workflows/ci.yml)
[![Deploy microk8s](https://github.com/wingadium1/spring-java-thread-performance/actions/workflows/deploy-microk8s.yml/badge.svg)](https://github.com/wingadium1/spring-java-thread-performance/actions/workflows/deploy-microk8s.yml)
[![Deploy Proxmox LXC](https://github.com/wingadium1/spring-java-thread-performance/actions/workflows/deploy-proxmox-lxc.yml/badge.svg)](https://github.com/wingadium1/spring-java-thread-performance/actions/workflows/deploy-proxmox-lxc.yml)

A comprehensive performance comparison project for different Spring Boot threading models:
- **Traditional Spring MVC** (Servlet: Tomcat, Blocking I/O)
- **Spring Boot with Virtual Threads** (Java 21)
- **Spring WebFlux** (Reactive, Reactor Netty, NIO)

## Key Features

- **Enhanced Database Simulator** - Realistic workload simulation with I/O, CPU, and memory patterns
- **Multiple Workload Profiles** - From light (10-50ms) to extreme (200-1000ms) loads
- **Hardware Limit Testing** - Push systems to breaking points to understand resource constraints
- **Comprehensive Metrics** - Thread count, memory usage, GC activity, latency distribution
- **Container-Ready** - Docker, Kubernetes, and VM deployment configurations
- **Production Scenarios** - Test real-world patterns: CRUD, batch processing, report generation

## Database Simulator

The enhanced database simulator provides realistic workload patterns:

### Workload Profiles

| Profile | I/O (ms) | CPU (ms) | Memory | Use Case |
|---------|----------|----------|---------|----------|
| LIGHT | 10-50 | - | - | Baseline testing |
| MEDIUM | 50-200 | - | - | Standard CRUD (default) |
| HEAVY | 100-500 | - | - | Slow queries |
| IO_PLUS_CPU | 50-200 | 10-50 | - | Query + processing |
| IO_PLUS_MEMORY | 50-200 | - | 1-5MB | Large result sets |
| REALISTIC_MIXED | 50-200 | 20-100 | 512KB-2MB | Real-world simulation |
| CPU_INTENSIVE | 10-50 | 100-500 | - | Data processing |
| EXTREME | 200-1000 | 50-200 | 5-10MB | Stress testing |

### Setting Workload Profile

```bash
# Via command line
mvn spring-boot:run -Dspring-boot.run.arguments="--app.workload.profile=REALISTIC_MIXED"

# Via application properties
app.workload.profile=EXTREME

# Via Spring profile
mvn spring-boot:run -Dspring-boot.run.arguments="--spring.profiles.active=heavy"
```

## Project Structure

```
spring-thread-performance/
├── common/                      # Shared utilities and models
│   └── DatabaseSimulator       # Enhanced I/O + CPU + memory simulator
├── spring-mvc-traditional/     # Traditional Spring MVC with Tomcat
├── spring-virtual-threads/     # Spring Boot with Virtual Threads (Java 21)
├── spring-webflux/            # Spring WebFlux with Reactor Netty
├── monitoring/                # Prometheus and Grafana configuration
└── docker-compose.yml         # Local deployment setup
```

## Requirements

- **Java 21** (for Virtual Threads support)
- **Maven 3.6+**
- **Docker** and **Docker Compose** (for containerized deployment)

## Building the Project

### Build All Modules

```bash
mvn clean package
```

### Build Individual Modules

```bash
# Traditional MVC
cd spring-mvc-traditional
mvn clean package

# Virtual Threads
cd spring-virtual-threads
mvn clean package

# WebFlux
cd spring-webflux
mvn clean package
```

### Build Docker Images with Jib

```bash
# Build all modules and create Docker images locally
mvn clean package jib:dockerBuild

# Or build individual images
cd spring-mvc-traditional && mvn jib:dockerBuild
cd spring-virtual-threads && mvn jib:dockerBuild
cd spring-webflux && mvn jib:dockerBuild
```

### Pre-built Docker Images

Docker images are automatically built and published to GitHub Container Registry (ghcr.io) for easy deployment:

```bash
# Pull images from GitHub Container Registry
docker pull ghcr.io/wingadium1/spring-java-thread-performance/spring-mvc-traditional:latest
docker pull ghcr.io/wingadium1/spring-java-thread-performance/spring-virtual-threads:latest
docker pull ghcr.io/wingadium1/spring-java-thread-performance/spring-webflux:latest

# Run directly from ghcr.io
docker run -d -p 8080:8080 ghcr.io/wingadium1/spring-java-thread-performance/spring-mvc-traditional:latest
docker run -d -p 8081:8080 ghcr.io/wingadium1/spring-java-thread-performance/spring-virtual-threads:latest
docker run -d -p 8082:8080 ghcr.io/wingadium1/spring-java-thread-performance/spring-webflux:latest
```

📘 **Image Documentation**:
- [.github/GHCR-QUICKSTART.md](.github/GHCR-QUICKSTART.md) - Quick start guide for GHCR setup (TL;DR)
- [.github/GHCR-AUTHENTICATION.md](.github/GHCR-AUTHENTICATION.md) - Complete GHCR authentication and token setup guide
- [.github/DOCKER-IMAGES.md](.github/DOCKER-IMAGES.md) - Docker image documentation and usage

## Running the Applications

### Run Locally (without Docker)

```bash
# Traditional MVC (port 8080)
cd spring-mvc-traditional
mvn spring-boot:run

# Virtual Threads (port 8081)
cd spring-virtual-threads
mvn spring-boot:run

# WebFlux (port 8082)
cd spring-webflux
mvn spring-boot:run
```

### Run with Docker Compose

```bash
# Build images first
mvn clean package jib:dockerBuild

# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all services
docker-compose down
```

## API Endpoints

All three applications expose the same REST API endpoints:

| Endpoint | Description |
|----------|-------------|
| `GET /api/hello` | Simple hello message |
| `GET /api/query` | Execute a simulated database query (profile-based timing) |
| `GET /api/query/{delay}` | Execute query with custom delay in milliseconds |
| `GET /api/multiple/{count}` | Execute multiple sequential queries |
| `GET /api/cpu/{durationMs}` | Execute CPU-intensive work for specified duration |
| `GET /api/stress?queries=N&cpuMs=M` | Combined stress test (I/O + CPU + memory) |
| `GET /api/info` | Application information, thread type, and workload profile |

### Health and Metrics

| Endpoint | Description |
|----------|-------------|
| `GET /actuator/health` | Health check endpoint |
| `GET /actuator/metrics` | Application metrics |
| `GET /actuator/prometheus` | Prometheus-formatted metrics |

## Testing the Applications

### Simple Test

```bash
# Test Traditional MVC
curl http://localhost:8080/api/query
curl http://localhost:8080/api/info

# Test Virtual Threads
curl http://localhost:8081/api/query
curl http://localhost:8081/api/info

# Test WebFlux
curl http://localhost:8082/api/query
curl http://localhost:8082/api/info
```

### Load Testing with Apache Bench

```bash
# Install Apache Bench
sudo apt-get install apache2-utils  # Ubuntu/Debian
brew install httpd  # macOS

# Test Traditional MVC (1000 requests, 50 concurrent)
ab -n 1000 -c 50 http://localhost:8080/api/query

# Test Virtual Threads (1000 requests, 50 concurrent)
ab -n 1000 -c 50 http://localhost:8081/api/query

# Test WebFlux (1000 requests, 50 concurrent)
ab -n 1000 -c 50 http://localhost:8082/api/query
```

### Load Testing with wrk

```bash
# Install wrk
sudo apt-get install wrk  # Ubuntu/Debian
brew install wrk  # macOS

# Test with 4 threads, 100 connections for 30 seconds
wrk -t4 -c100 -d30s http://localhost:8080/api/query
wrk -t4 -c100 -d30s http://localhost:8081/api/query
wrk -t4 -c100 -d30s http://localhost:8082/api/query

# Test with higher load (8 threads, 500 connections)
wrk -t8 -c500 -d60s http://localhost:8080/api/query
wrk -t8 -c500 -d60s http://localhost:8081/api/query
wrk -t8 -c500 -d60s http://localhost:8082/api/query
```

## Monitoring

### Prometheus

Access Prometheus at: http://localhost:9090

Useful queries:
```promql
# Request rate
rate(http_server_requests_seconds_count[1m])

# Response time (95th percentile)
histogram_quantile(0.95, rate(http_server_requests_seconds_bucket[1m]))

# JVM threads
jvm_threads_live_threads

# CPU usage
system_cpu_usage
```

### Grafana

Access Grafana at: http://localhost:3000
- Username: `admin`
- Password: `admin`

Prometheus datasource is pre-configured.

## Deployment on Proxmox

### VM Deployment

1. Create a VM with recommended specs:
   - 8 CPU cores
   - 16GB RAM
   - Ubuntu 22.04 LTS

2. Install Java 21:
```bash
sudo apt update
sudo apt install -y openjdk-21-jdk
```

3. Transfer and run the JAR:
```bash
# Transfer JAR
scp spring-mvc-traditional/target/*.jar user@proxmox-vm:/opt/app/

# Run application
java -Xms512m -Xmx2g -jar /opt/app/spring-mvc-traditional-1.0.0-SNAPSHOT.jar
```

### Container Deployment on Proxmox

1. Install Docker on Proxmox VM:
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

2. Transfer images:
```bash
# Save images
docker save spring-performance/spring-mvc-traditional > mvc-traditional.tar
docker save spring-performance/spring-virtual-threads > virtual-threads.tar
docker save spring-performance/spring-webflux > webflux.tar

# Transfer to Proxmox VM
scp *.tar user@proxmox-vm:/tmp/

# Load images on Proxmox
docker load < /tmp/mvc-traditional.tar
docker load < /tmp/virtual-threads.tar
docker load < /tmp/webflux.tar
```

3. Run containers:
```bash
docker run -d -p 8080:8080 \
  -e JAVA_TOOL_OPTIONS="-Xms512m -Xmx2g" \
  --name spring-mvc \
  spring-performance/spring-mvc-traditional

docker run -d -p 8081:8081 \
  -e JAVA_TOOL_OPTIONS="-Xms512m -Xmx2g" \
  --name spring-virtual \
  spring-performance/spring-virtual-threads

docker run -d -p 8082:8082 \
  -e JAVA_TOOL_OPTIONS="-Xms512m -Xmx2g" \
  --name spring-webflux \
  spring-performance/spring-webflux
```

## Load Balancer Configuration

### Nginx Load Balancer

Create `/etc/nginx/sites-available/spring-performance`:

```nginx
upstream spring_backends {
    least_conn;
    server 192.168.1.10:8080;  # Traditional MVC
    server 192.168.1.11:8081;  # Virtual Threads
    server 192.168.1.12:8082;  # WebFlux
}

server {
    listen 80;
    server_name performance.example.com;

    location / {
        proxy_pass http://spring_backends;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /actuator/health {
        proxy_pass http://spring_backends;
    }
}
```

Enable and restart:
```bash
sudo ln -s /etc/nginx/sites-available/spring-performance /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### HAProxy Load Balancer

Create `/etc/haproxy/haproxy.cfg`:

```haproxy
frontend spring_frontend
    bind *:80
    default_backend spring_backend

backend spring_backend
    balance roundrobin
    option httpchk GET /actuator/health
    http-check expect status 200
    server mvc 192.168.1.10:8080 check
    server virtual 192.168.1.11:8081 check
    server webflux 192.168.1.12:8082 check
```

## Performance Comparison

### Expected Characteristics

| Approach | Thread Model | Best For | Limitations |
|----------|--------------|----------|-------------|
| **Traditional MVC** | Platform threads (1 thread per request) | Low to medium concurrency, simple blocking I/O | Thread pool exhaustion under high load |
| **Virtual Threads** | Virtual threads (millions possible) | High concurrency with blocking I/O | Requires Java 21, still blocking calls |
| **WebFlux** | Event loop (few threads) | High concurrency with non-blocking I/O | Complex programming model, steep learning curve |

### Performance Testing Scenarios

1. **Low Load (100 concurrent users)**
   - All approaches perform similarly
   - Traditional MVC may have slight edge due to simplicity

2. **Medium Load (500 concurrent users)**
   - Virtual Threads start showing advantages
   - Traditional MVC may show thread pool saturation
   - WebFlux handles efficiently with event loop

3. **High Load (1000+ concurrent users)**
   - Virtual Threads excel at handling many concurrent blocking operations
   - Traditional MVC struggles with thread pool limits
   - WebFlux performs best if properly implemented with non-blocking I/O

4. **CPU-Intensive Tasks**
   - All approaches similar (bound by CPU)
   - Traditional MVC may have slight advantage

5. **I/O-Intensive Tasks (simulated here)**
   - Virtual Threads and WebFlux significantly outperform Traditional MVC
   - Virtual Threads easier to understand and maintain

## Key Metrics to Compare

- **Throughput**: Requests per second
- **Latency**: Response time (p50, p95, p99)
- **Resource Usage**: CPU, Memory, Thread count
- **Concurrency**: Maximum concurrent requests handled
- **Errors**: Error rate under load

## CI/CD and Deployment

This project uses GitHub Actions with self-hosted runners for automated build and deployment with multiple deployment options:

### Deployment Options:
1. **Proxmox VM** - Traditional VM deployment with SSH
2. **Proxmox LXC** - Lightweight containers created via Proxmox API ⭐ **Recommended**
3. **microk8s** - Kubernetes deployment on Proxmox VM
4. **Monitoring Stack** - Prometheus + Grafana on separate host

### Documentation:
- **[.github/workflows/README.md](.github/workflows/README.md)** - All workflows overview
- **[.github/PROXMOX-SETUP.md](.github/PROXMOX-SETUP.md)** - Proxmox VM deployment guide
- **[.github/PROXMOX-LXC-GUIDE.md](.github/PROXMOX-LXC-GUIDE.md)** - Proxmox LXC container guide
- **[.github/MICROK8S-GUIDE.md](.github/MICROK8S-GUIDE.md)** - microk8s deployment guide
- **[.github/MONITORING-GUIDE.md](.github/MONITORING-GUIDE.md)** - Prometheus/Grafana monitoring setup
- **[.github/SECRETS-TEMPLATE.md](.github/SECRETS-TEMPLATE.md)** - GitHub Secrets configuration
- **[monitoring/README.md](monitoring/README.md)** - Monitoring configuration files

## Additional Documentation

- **[QUICKSTART.md](QUICKSTART.md)** - Get started in 5 minutes
- **[TESTING-GUIDE.md](TESTING-GUIDE.md)** - Comprehensive performance testing strategies
- **[HARDWARE-LIMITS-GUIDE.md](HARDWARE-LIMITS-GUIDE.md)** - Push systems to hardware limits
- **[DIFFERENCES.md](DIFFERENCES.md)** - Detailed comparison of implementations
- **[deployment/README.md](deployment/README.md)** - VM deployment guide
- **[deployment/kubernetes/README.md](deployment/kubernetes/README.md)** - Kubernetes deployment guide

## License

This project is licensed under the MIT License - see the LICENSE file for details.