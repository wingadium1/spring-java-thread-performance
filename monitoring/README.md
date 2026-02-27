# Monitoring Configuration

This directory contains Prometheus and Grafana configuration for monitoring Spring Boot applications deployed in Proxmox LXC containers.

## Files Overview

| File | Description |
|------|-------------|
| `prometheus-lxc.yml` | Prometheus configuration for LXC containers (use this) |
| `prometheus.yml` | Original Prometheus config for Docker Compose |
| `prometheus-alerts.yml` | Alert rules for Prometheus |
| `grafana-datasource.yml` | Grafana datasource configuration |
| `docker-compose.yml` | Docker Compose file for monitoring stack |
| `setup-monitoring.sh` | Interactive setup script for monitoring host |
| `dashboards/` | Grafana dashboard JSON files |

## Quick Start

### Automatic Deployment (GitHub Actions)

1. Configure GitHub secrets (see [../.github/MONITORING-GUIDE.md](../.github/MONITORING-GUIDE.md))
2. Deploy using your CI/CD pipeline or run `setup-monitoring.sh`
3. Access Grafana at `http://monitoring-host:3000`

### Manual Deployment

```bash
# 1. Copy this directory to monitoring host
scp -r monitoring/ user@monitoring-host:~/

# 2. SSH to monitoring host
ssh user@monitoring-host

# 3. Run setup script
cd ~/monitoring
./setup-monitoring.sh

# Or deploy with Docker Compose
docker-compose up -d
```

## Configuration

### Prometheus Targets

Edit `prometheus-lxc.yml` and replace IP placeholders:
```yaml
- targets: ['192.168.1.200:8080']  # Container 200
- targets: ['192.168.1.201:8081']  # Container 201
- targets: ['192.168.1.202:8082']  # Container 202
```

### Grafana Admin Password

Set in Docker Compose or environment variable:
```bash
export GRAFANA_ADMIN_PASSWORD="your-secure-password"
docker-compose up -d
```

## Dashboards

### Available Dashboards

1. **spring-performance-comparison.json**
   - Request rate comparison
   - Response time (p95)
   - JVM memory usage
   - Thread count
   - CPU usage
   - HTTP errors
   - GC activity

2. **jvm-metrics.json**
   - Detailed JVM heap/non-heap memory
   - Thread states and pools
   - GC pause times
   - Class loading
   - Buffer pools

### Import Dashboards

**Option 1: Auto-import (Docker Compose)**
- Place JSON files in `dashboards/` directory
- Grafana will auto-load them on startup

**Option 2: Manual import**
1. Open Grafana: `http://monitoring-host:3000`
2. Click **+** → **Import**
3. Upload dashboard JSON
4. Select Prometheus datasource

## Accessing Services

- **Prometheus**: `http://monitoring-host:9090`
  - Targets: `/targets`
  - Alerts: `/alerts`
  - Query: `/graph`

- **Grafana**: `http://monitoring-host:3000`
  - Login: admin / (your password)
  - Dashboards: Left menu → Dashboards

## Monitoring Metrics

All Spring Boot applications expose metrics at:
- `http://container-ip:port/actuator/prometheus`
- `http://container-ip:port/actuator/health`
- `http://container-ip:port/actuator/metrics`

Example queries:
```bash
# Test metrics endpoint
curl http://192.168.1.200:8080/actuator/prometheus | head -50

# Check specific metric
curl http://192.168.1.200:8080/actuator/metrics/jvm.memory.used

# Health check
curl http://192.168.1.200:8080/actuator/health
```

## Useful PromQL Queries

```promql
# Request rate per application
sum by (application) (rate(http_server_requests_seconds_count[1m]))

# Memory usage percentage
(jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"}) * 100

# Thread count
jvm_threads_live_threads

# Response time p95
histogram_quantile(0.95, rate(http_server_requests_seconds_bucket[5m]))

# Error rate
rate(http_server_requests_seconds_count{status=~"5.."}[1m])
```

## Troubleshooting

### Prometheus Can't Scrape

```bash
# Check Prometheus logs
docker logs prometheus

# Test connectivity from monitoring host
curl http://<container-ip>:8080/actuator/prometheus

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets | jq
```

### Grafana Shows No Data

```bash
# Check Grafana logs
docker logs grafana

# Verify datasource
curl -u admin:password http://localhost:3000/api/datasources

# Check Prometheus has data
curl "http://localhost:9090/api/v1/query?query=up"
```

### Containers Not Reachable

Check network connectivity:
```bash
# From monitoring host
ping <container-ip>
telnet <container-ip> 8080

# Check firewall on containers (from Proxmox)
pct exec 200 -- iptables -L
```

## Maintenance

### Update Containers

```bash
docker pull prom/prometheus:latest
docker pull grafana/grafana:latest
docker-compose down
docker-compose up -d
```

### Backup Data

```bash
# Backup Prometheus data
docker exec prometheus tar czf - /prometheus > prometheus-backup.tar.gz

# Backup Grafana data
docker exec grafana tar czf - /var/lib/grafana > grafana-backup.tar.gz
```

### Reload Prometheus Config

```bash
# After editing prometheus.yml
curl -X POST http://localhost:9090/-/reload
```

## Architecture

```
┌──────────────────────────────────────────┐
│         Monitoring Host (Docker)          │
│                                           │
│  ┌─────────────┐      ┌──────────────┐  │
│  │ Prometheus  │◄────►│   Grafana    │  │
│  │   :9090     │      │    :3000     │  │
│  └──────┬──────┘      └──────────────┘  │
└─────────┼─────────────────────────────────┘
          │ Scrapes every 15s
          │
    ┌─────┴─────┬──────────┬──────────┐
    │           │          │          │
┌───▼─────┐ ┌──▼─────┐ ┌──▼─────┐ ┌──▼─────┐
│ CT 200  │ │ CT 201 │ │ CT 202 │ │Optional│
│ MVC     │ │Virtual │ │WebFlux │ │ Node   │
│ :8080   │ │Threads │ │ :8082  │ │Export  │
└─────────┘ └────────┘ └────────┘ └────────┘
```

## Performance Impact

Monitoring overhead per application:
- **CPU**: <1%
- **Memory**: ~50MB for Micrometer
- **Network**: ~10KB per scrape (15s interval)
- **Disk**: Prometheus ~1MB/day per metric

## Next Steps

1. ✅ Set up monitoring host
2. ✅ Configure container IPs in prometheus.yml
3. ✅ Deploy monitoring stack
4. ✅ Access Grafana and import dashboards
5. ✅ Set up alerts (optional)

For detailed setup instructions, see [../.github/MONITORING-GUIDE.md](../.github/MONITORING-GUIDE.md)
