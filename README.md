# Spring Boot Thread Performance Comparison

A comprehensive performance comparison project for different Spring Boot threading models:
- **Traditional Spring MVC** (Servlet: Tomcat, Blocking I/O)
- **Spring Boot with Virtual Threads** (Java 21)
- **Spring WebFlux** (Reactive, Reactor Netty, NIO)

## Project Structure

```
spring-thread-performance/
├── common/                      # Shared utilities and models
│   └── DatabaseSimulator       # Simulates blocking database calls
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
# Build all modules and create Docker images
mvn clean package jib:dockerBuild

# Or build individual images
cd spring-mvc-traditional && mvn jib:dockerBuild
cd spring-virtual-threads && mvn jib:dockerBuild
cd spring-webflux && mvn jib:dockerBuild
```

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
| `GET /api/query` | Execute a simulated database query (50-200ms) |
| `GET /api/query/{delay}` | Execute query with custom delay in milliseconds |
| `GET /api/multiple/{count}` | Execute multiple sequential queries |
| `GET /api/info` | Application information and thread type |

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

## License

This project is licensed under the MIT License - see the LICENSE file for details.