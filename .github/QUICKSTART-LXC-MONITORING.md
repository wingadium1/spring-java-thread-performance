# Quick Start Guide - LXC with Monitoring

Complete guide to deploy Spring Boot apps to Proxmox LXC containers with Prometheus/Grafana monitoring.

## Prerequisites Checklist

- [ ] Proxmox VE 7.0+ server
- [ ] Ubuntu 22.04 LXC template downloaded on Proxmox
- [ ] Separate monitoring host with Docker installed
- [ ] GitHub self-hosted runner configured
- [ ] Network connectivity between monitoring host and Proxmox network

## Step 1: Configure GitHub Secrets

Go to: `https://github.com/wingadium1/spring-java-thread-performance/settings/secrets/actions`

### For Proxmox API (Required)
```
PROXMOX_API_HOST=192.168.1.100
PROXMOX_API_TOKEN_ID=root@pam!github-actions
PROXMOX_API_SECRET=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
PROXMOX_NODE=pve
PROXMOX_SSH_KEY=-----BEGIN OPENSSH PRIVATE KEY-----...
```

### For Monitoring (Required)
```
MONITORING_HOST=192.168.1.200
MONITORING_USER=ubuntu
MONITORING_SSH_KEY=-----BEGIN OPENSSH PRIVATE KEY-----...
GRAFANA_ADMIN_PASSWORD=YourSecurePassword123!
```

## Step 2: Deploy LXC Containers

### Option A: Via GitHub Actions (Recommended)
1. Go to **Actions** tab
2. Select **"Deploy to Proxmox LXC Containers"**
3. Click **"Run workflow"**
4. Wait for completion (~5 minutes)
5. Note the container IPs from the workflow output

### Option B: Manual Deployment
```bash
# SSH to Proxmox
ssh root@proxmox-server

# Create containers manually
pct create 200 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname spring-mvc-traditional --memory 2048 --cores 2 \
  --rootfs local-lvm:8 --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --unprivileged 1 --start 1

pct create 201 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname spring-virtual-threads --memory 2048 --cores 2 \
  --rootfs local-lvm:8 --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --unprivileged 1 --start 1

pct create 202 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname spring-webflux --memory 2048 --cores 2 \
  --rootfs local-lvm:8 --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --unprivileged 1 --start 1

# Then deploy apps using the workflow
```

## Step 3: Verify LXC Deployments

```bash
# SSH to Proxmox
ssh root@proxmox-server

# Check container status
pct list | grep "200\|201\|202"

# Get container IPs
pct exec 200 -- hostname -I | awk '{print $1}'
pct exec 201 -- hostname -I | awk '{print $1}'
pct exec 202 -- hostname -I | awk '{print $1}'

# Verify applications are running
pct exec 200 -- systemctl status spring-mvc-traditional
pct exec 201 -- systemctl status spring-virtual-threads
pct exec 202 -- systemctl status spring-webflux

# Test health endpoints
pct exec 200 -- curl http://localhost:8080/actuator/health
pct exec 201 -- curl http://localhost:8081/actuator/health
pct exec 202 -- curl http://localhost:8082/actuator/health

# Test metrics endpoints
pct exec 200 -- curl http://localhost:8080/actuator/prometheus | head -20
```

## Step 4: Deploy Monitoring Stack

### Option A: Via GitHub Actions (Recommended)
1. Go to **Actions** tab
2. Select **"Deploy Monitoring Stack (Prometheus + Grafana)"**
3. Click **"Run workflow"**
4. Wait for completion (~3 minutes)
5. Note the access URLs from output

### Option B: Manual Deployment
```bash
# SSH to monitoring host
ssh user@monitoring-host

# Clone monitoring configs
git clone https://github.com/wingadium1/spring-java-thread-performance.git
cd spring-java-thread-performance/monitoring

# Run setup script
./setup-monitoring.sh

# Or use Docker Compose
# Edit prometheus-lxc.yml with actual IPs
# Set password: export GRAFANA_ADMIN_PASSWORD="YourPassword"
# Deploy: docker-compose up -d
```

## Step 5: Access Monitoring

### Prometheus
```
URL: http://monitoring-host:9090
Use: Query metrics, check targets, view alerts
```

**Verify targets:**
- Go to: http://monitoring-host:9090/targets
- All three Spring apps should show as "UP"

### Grafana
```
URL: http://monitoring-host:3000
Username: admin
Password: (your GRAFANA_ADMIN_PASSWORD secret)
```

**Import dashboards:**
1. Click **+** → **Import**
2. Upload `monitoring/dashboards/spring-performance-comparison.json`
3. Upload `monitoring/dashboards/jvm-metrics.json`
4. Select **Prometheus** datasource
5. Click **Import**

## Step 6: Generate Load and Monitor

### Start Load Test
```bash
# Install wrk if not available
sudo apt-get install wrk

# Test Spring MVC Traditional
wrk -t4 -c100 -d30s http://container-200-ip:8080/api/cpu

# Test Spring Virtual Threads
wrk -t4 -c100 -d30s http://container-201-ip:8081/api/cpu

# Test Spring WebFlux
wrk -t4 -c100 -d30s http://container-202-ip:8082/api/cpu
```

### Watch Real-Time Metrics in Grafana
1. Open **Performance Comparison** dashboard
2. Set refresh interval to **5 seconds**
3. Run load tests and observe:
   - Request rate differences
   - Response time patterns
   - Memory usage
   - Thread count variations
   - CPU utilization

## Troubleshooting

### Container Not Responding
```bash
ssh root@proxmox-server
pct status 200
pct exec 200 -- systemctl status spring-mvc-traditional
pct exec 200 -- journalctl -u spring-mvc-traditional -n 50
```

### Prometheus Can't Scrape
```bash
# From monitoring host, test connectivity
curl http://container-ip:8080/actuator/prometheus

# Check Prometheus logs
docker logs prometheus

# Verify targets in Prometheus UI
# http://monitoring-host:9090/targets
```

### Grafana Shows No Data
```bash
# Check datasource connection
curl -u admin:password http://monitoring-host:3000/api/datasources

# Test Prometheus query
curl "http://monitoring-host:9090/api/v1/query?query=up"

# Check Grafana logs
docker logs grafana
```

## Architecture Summary

```
┌──────────────────────────────────────────────────────────┐
│                  GitHub Actions Runner                    │
│                                                            │
│  Workflow 1: Deploy LXC Containers                       │
│  Workflow 2: Deploy Monitoring Stack                     │
└─────────────┬──────────────────────┬─────────────────────┘
              │                      │
       Creates via API        Deploys Docker
              │                      │
┌─────────────▼──────────┐  ┌────────▼─────────┐
│   Proxmox Server       │  │ Monitoring Host  │
│                        │  │                  │
│  ┌─────────────────┐  │  │ ┌──────────────┐ │
│  │ CT 200          │  │  │ │ Prometheus   │ │
│  │ MVC :8080       │◄─┼──┼─┤ :9090        │ │
│  │ /actuator/*     │  │  │ └──────┬───────┘ │
│  └─────────────────┘  │  │        │         │
│                       │  │ ┌──────▼───────┐ │
│  ┌─────────────────┐  │  │ │ Grafana      │ │
│  │ CT 201          │◄─┼──┼─┤ :3000        │ │
│  │ Virtual :8081   │  │  │ │ (Dashboards) │ │
│  │ /actuator/*     │  │  │ └──────────────┘ │
│  └─────────────────┘  │  └──────────────────┘
│                       │         ▲
│  ┌─────────────────┐  │         │
│  │ CT 202          │◄─┼─────────┘
│  │ WebFlux :8082   │  │   Scrapes every 15s
│  │ /actuator/*     │  │
│  └─────────────────┘  │
└────────────────────────┘
```

## Key Metrics to Watch

### Performance Comparison
- **Throughput**: requests/second (higher is better)
- **Latency p95**: 95th percentile response time (lower is better)
- **Memory**: heap usage (lower is better)
- **Threads**: thread count (virtual threads use fewer)

### Resource Utilization
- **CPU**: process CPU usage %
- **GC**: garbage collection frequency and pause time
- **Errors**: HTTP 5xx error rate

## Expected Results

Based on implementation patterns:

| Metric | Traditional MVC | Virtual Threads | WebFlux |
|--------|----------------|-----------------|---------|
| **Throughput** | Moderate | High | Very High |
| **Latency** | Moderate | Low | Very Low |
| **Memory** | Moderate | Moderate | Low |
| **Threads** | Many (100+) | Many (dynamic) | Few (10-20) |
| **CPU** | High under load | Moderate | Low |

## Next Steps After Setup

1. ✅ Monitor performance under various loads
2. ✅ Compare metrics across implementations
3. ✅ Tune resource limits based on actual usage
4. ✅ Set up alerting for critical thresholds
5. ✅ Export dashboards for presentations
6. ✅ Document findings in performance reports

## Support & Documentation

- **LXC Guide**: [.github/PROXMOX-LXC-GUIDE.md](.github/PROXMOX-LXC-GUIDE.md)
- **Monitoring Guide**: [.github/MONITORING-GUIDE.md](.github/MONITORING-GUIDE.md)
- **Monitoring Configs**: [monitoring/README.md](monitoring/README.md)
- **Secrets Template**: [.github/SECRETS-TEMPLATE.md](.github/SECRETS-TEMPLATE.md)
- **All Workflows**: [.github/workflows/README.md](.github/workflows/README.md)

## Success Criteria

✅ All 3 LXC containers running
✅ All applications healthy (200 OK)
✅ Prometheus scraping all targets (UP status)
✅ Grafana dashboards showing metrics
✅ No security vulnerabilities (CodeQL: 0 alerts)

**You're ready to compare Spring Boot performance patterns! 🚀**
