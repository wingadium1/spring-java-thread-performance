# Monitoring Stack Deployment Guide

This guide covers deploying Prometheus and Grafana on a separate monitoring host to monitor Spring Boot applications running in Proxmox LXC containers.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Monitoring Host                          │
│  ┌──────────────┐              ┌──────────────┐            │
│  │  Prometheus  │◄─────────────┤   Grafana    │            │
│  │  :9090       │              │   :3000      │            │
│  └──────┬───────┘              └──────────────┘            │
└─────────┼──────────────────────────────────────────────────┘
          │
          │ Scrapes metrics every 15s
          │
    ┌─────┴─────┬─────────────┬─────────────┐
    │           │             │             │
┌───▼────┐  ┌───▼────┐   ┌───▼────┐   ┌────▼────┐
│ LXC 200│  │ LXC 201│   │ LXC 202│   │ Proxmox │
│  MVC   │  │Virtual │   │WebFlux │   │  Node   │
│ :8080  │  │Threads │   │ :8082  │   │ (opt)   │
│        │  │ :8081  │   │        │   │         │
└────────┘  └────────┘   └────────┘   └─────────┘
```

## Prerequisites

### 1. Monitoring Host Requirements

A separate VM or physical server with:
- **OS**: Ubuntu 22.04 LTS (or any Linux)
- **Resources**: 2 CPU cores, 4GB RAM minimum
- **Software**: Docker installed
- **Network**: Access to LXC containers on Proxmox network

### 2. Install Docker on Monitoring Host

```bash
# SSH to monitoring host
ssh user@monitoring-host

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify Docker installation
docker --version
docker run hello-world
```

### 3. LXC Containers Must Be Running

Ensure your LXC containers are deployed and accessible:
- Container 200: spring-mvc-traditional on port 8080
- Container 201: spring-virtual-threads on port 8081
- Container 202: spring-webflux on port 8082

## GitHub Secrets Configuration

Add these secrets to your GitHub repository:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `MONITORING_HOST` | IP or hostname of monitoring host | `192.168.1.200` |
| `MONITORING_USER` | SSH username | `ubuntu` |
| `MONITORING_SSH_KEY` | SSH private key | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
| `GRAFANA_ADMIN_PASSWORD` | Grafana admin password | `SecurePassword123!` |

Plus the existing Proxmox secrets (to fetch container IPs):
- `PROXMOX_API_HOST`
- `PROXMOX_API_TOKEN_ID`
- `PROXMOX_API_SECRET`
- `PROXMOX_NODE`

### Generate SSH Key for Monitoring Host

```bash
# Generate key
ssh-keygen -t ed25519 -C "github-actions-monitoring" -f ~/.ssh/monitoring_deploy

# Copy to monitoring host
ssh-copy-id -i ~/.ssh/monitoring_deploy.pub user@monitoring-host

# Test connection
ssh -i ~/.ssh/monitoring_deploy user@monitoring-host "docker ps"

# Copy private key for GitHub Secret
cat ~/.ssh/monitoring_deploy
```

## Automated Deployment Scripts

Use the repository scripts to automate monitoring deployment:

1. **Fetch and configure targets** in Prometheus config
2. **Deploy Prometheus** Docker container
3. **Deploy Grafana** Docker container with datasource
4. **Verify** all targets are up and healthy

### Trigger Deployment

```bash
# Push changes to monitoring configs
git add monitoring/
git commit -m "Update monitoring configuration"
git push origin main

# Or run monitoring setup script directly on monitoring host
# ./monitoring/setup-monitoring.sh
```

## Manual Deployment

If you prefer to deploy manually without GitHub Actions:

### Step 1: Get LXC Container IPs

```bash
# SSH to Proxmox server
ssh root@proxmox-server

# Get container IPs
pct exec 200 -- hostname -I | awk '{print $1}'  # MVC Traditional
pct exec 201 -- hostname -I | awk '{print $1}'  # Virtual Threads
pct exec 202 -- hostname -I | awk '{print $1}'  # WebFlux
```

### Step 2: Configure Prometheus

```bash
# SSH to monitoring host
ssh user@monitoring-host

# Create directory
mkdir -p ~/monitoring/prometheus

# Create prometheus.yml
cat > ~/monitoring/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'proxmox-lxc'
    environment: 'production'

scrape_configs:
  - job_name: 'spring-mvc-traditional'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['<CONTAINER_200_IP>:8080']
        labels:
          application: 'spring-mvc-traditional'
          type: 'blocking-io'

  - job_name: 'spring-virtual-threads'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['<CONTAINER_201_IP>:8081']
        labels:
          application: 'spring-virtual-threads'
          type: 'virtual-threads'

  - job_name: 'spring-webflux'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['<CONTAINER_202_IP>:8082']
        labels:
          application: 'spring-webflux'
          type: 'reactive-nio'

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF

# Replace <CONTAINER_XXX_IP> with actual IPs
sed -i 's/<CONTAINER_200_IP>/192.168.1.200/g' ~/monitoring/prometheus/prometheus.yml
sed -i 's/<CONTAINER_201_IP>/192.168.1.201/g' ~/monitoring/prometheus/prometheus.yml
sed -i 's/<CONTAINER_202_IP>/192.168.1.202/g' ~/monitoring/prometheus/prometheus.yml
```

### Step 3: Deploy Prometheus

```bash
# Start Prometheus
docker run -d \
  --name prometheus \
  --restart unless-stopped \
  -p 9090:9090 \
  -v ~/monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro \
  prom/prometheus:latest \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/prometheus \
  --web.enable-lifecycle

# Verify Prometheus is running
docker ps | grep prometheus
curl http://localhost:9090/-/ready

# Check targets
curl http://localhost:9090/api/v1/targets
```

### Step 4: Configure Grafana

```bash
# Create Grafana directories
mkdir -p ~/monitoring/grafana/provisioning/{datasources,dashboards}
mkdir -p ~/monitoring/grafana/dashboards

# Create datasource configuration
cat > ~/monitoring/grafana/provisioning/datasources/datasource.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

# Create dashboard provisioning config
cat > ~/monitoring/grafana/provisioning/dashboards/dashboard.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'Spring Performance Dashboards'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF
```

### Step 5: Deploy Grafana

```bash
# Start Grafana with Docker network
docker network create monitoring 2>/dev/null || true

# Re-create Prometheus with network
docker stop prometheus
docker rm prometheus
docker run -d \
  --name prometheus \
  --restart unless-stopped \
  --network monitoring \
  -p 9090:9090 \
  -v ~/monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro \
  prom/prometheus:latest \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/prometheus \
  --web.enable-lifecycle

# Start Grafana
docker run -d \
  --name grafana \
  --restart unless-stopped \
  --network monitoring \
  -p 3000:3000 \
  -e "GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}" \
  -e "GF_USERS_ALLOW_SIGN_UP=false" \
  -v ~/monitoring/grafana/provisioning/datasources:/etc/grafana/provisioning/datasources:ro \
  -v ~/monitoring/grafana/provisioning/dashboards:/etc/grafana/provisioning/dashboards:ro \
  -v ~/monitoring/grafana/dashboards:/var/lib/grafana/dashboards:ro \
  grafana/grafana:latest

# Verify both containers are running
docker ps
```

### Step 6: Verify Setup

```bash
# Check Prometheus
curl http://localhost:9090/-/healthy
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[].health'

# Check Grafana
curl http://localhost:3000/api/health

# Access in browser
# Prometheus: http://monitoring-host:9090
# Grafana: http://monitoring-host:3000 (admin/your-password)
```

## Accessing Metrics from Containers

### Test Metrics Endpoints

```bash
# From monitoring host, test each container
curl http://<container-200-ip>:8080/actuator/prometheus | head -20
curl http://<container-201-ip>:8081/actuator/prometheus | head -20
curl http://<container-202-ip>:8082/actuator/prometheus | head -20

# Check health endpoints
curl http://<container-200-ip>:8080/actuator/health
curl http://<container-201-ip>:8081/actuator/health
curl http://<container-202-ip>:8082/actuator/health
```

### If Metrics Are Not Accessible

Check network connectivity from monitoring host:

```bash
# Test network connectivity
ping <container-ip>
telnet <container-ip> 8080

# Check if containers allow external access
# SSH to Proxmox and check iptables in containers
ssh root@proxmox-server
pct exec 200 -- iptables -L
```

## Grafana Setup

### First Login

1. Open browser: `http://monitoring-host:3000`
2. Login with:
   - Username: `admin`
   - Password: (your GRAFANA_ADMIN_PASSWORD secret)
3. Prometheus datasource should be automatically configured

### Import Dashboards

The repository includes a pre-configured dashboard at `monitoring/dashboards/spring-performance-comparison.json`.

**To import manually:**
1. In Grafana, click **+** → **Import**
2. Upload `monitoring/dashboards/spring-performance-comparison.json`
3. Select Prometheus datasource
4. Click **Import**

### Key Metrics to Monitor

| Metric | Description | Query |
|--------|-------------|-------|
| **Request Rate** | Requests per second | `rate(http_server_requests_seconds_count[1m])` |
| **Response Time** | 95th percentile | `histogram_quantile(0.95, rate(http_server_requests_seconds_bucket[1m]))` |
| **JVM Memory** | Heap usage | `jvm_memory_used_bytes{area="heap"}` |
| **Thread Count** | Active threads | `jvm_threads_live_threads` |
| **CPU Usage** | Process CPU | `process_cpu_usage` |
| **GC Activity** | GC pause time | `rate(jvm_gc_pause_seconds_count[1m])` |

## Docker Compose Alternative

For easier management, you can use Docker Compose:

```yaml
# ~/monitoring/docker-compose.yml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.enable-lifecycle'
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - ./grafana/provisioning/datasources:/etc/grafana/provisioning/datasources:ro
      - ./grafana/provisioning/dashboards:/etc/grafana/provisioning/dashboards:ro
      - ./grafana/dashboards:/var/lib/grafana/dashboards:ro
      - grafana-data:/var/lib/grafana
    depends_on:
      - prometheus
    networks:
      - monitoring

volumes:
  prometheus-data:
  grafana-data:

networks:
  monitoring:
    driver: bridge
```

Deploy with:
```bash
cd ~/monitoring

# Set Grafana password as environment variable
export GRAFANA_ADMIN_PASSWORD="YourSecurePassword123!"

# Start services
docker-compose up -d
docker-compose ps
```

## Updating Monitoring Configuration

### Update Prometheus Config

```bash
# Edit config on monitoring host
ssh user@monitoring-host
nano ~/monitoring/prometheus/prometheus.yml

# Reload Prometheus (hot reload)
curl -X POST http://localhost:9090/-/reload

# Or restart container
docker restart prometheus
```

### Add New Dashboard

```bash
# Copy dashboard JSON to monitoring host
scp new-dashboard.json user@monitoring-host:~/monitoring/grafana/dashboards/

# Grafana will auto-load it within 10 seconds
```

## Alerting (Optional)

### Configure Prometheus Alerts

Create alert rules:

```yaml
# ~/monitoring/prometheus/alert.rules.yml
groups:
  - name: spring_boot_alerts
    interval: 30s
    rules:
      - alert: HighResponseTime
        expr: histogram_quantile(0.95, rate(http_server_requests_seconds_bucket[5m])) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High response time on {{ $labels.application }}"
          description: "95th percentile response time is {{ $value }}s"

      - alert: HighErrorRate
        expr: rate(http_server_requests_seconds_count{status=~"5.."}[5m]) > 0.05
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "High error rate on {{ $labels.application }}"
          description: "Error rate is {{ $value }} req/s"

      - alert: HighMemoryUsage
        expr: jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"} > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.application }}"
          description: "Heap usage is {{ $value | humanizePercentage }}"

      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.job }} is down"
          description: "{{ $labels.job }} has been down for more than 1 minute"
```

Update `prometheus.yml` to include:
```yaml
rule_files:
  - 'alert.rules.yml'
```

### Configure Alertmanager (Optional)

```bash
# Create alertmanager config
cat > ~/monitoring/alertmanager/alertmanager.yml << 'EOF'
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'cluster']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'email-notifications'

receivers:
  - name: 'email-notifications'
    email_configs:
      - to: 'your-email@example.com'
        from: 'alertmanager@example.com'
        smarthost: 'smtp.gmail.com:587'
        auth_username: 'your-email@example.com'
        auth_password: 'your-app-password'
EOF

# Deploy Alertmanager
docker run -d \
  --name alertmanager \
  --restart unless-stopped \
  --network monitoring \
  -p 9093:9093 \
  -v ~/monitoring/alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro \
  prom/alertmanager:latest
```

## Monitoring Best Practices

### 1. Resource Allocation

**Prometheus retention:**
- Default: 15 days
- Adjust with: `--storage.tsdb.retention.time=30d`

**Grafana data:**
- Dashboards stored in volume
- Export regularly: Settings → Export

### 2. Network Configuration

**Firewall rules on LXC containers:**
```bash
# Allow Prometheus scraping from monitoring host
ssh root@proxmox-server
for CTID in 200 201 202; do
  pct exec $CTID -- iptables -A INPUT -s <monitoring-host-ip> -p tcp --dport 8080:8082 -j ACCEPT
done
```

### 3. Performance Impact

Monitoring overhead:
- **Scrape interval**: 15s (adjustable)
- **CPU impact**: <1% per application
- **Memory impact**: ~50MB for Micrometer
- **Network**: ~10KB/scrape

## Troubleshooting

### Prometheus Can't Scrape Targets

```bash
# Check Prometheus logs
docker logs prometheus

# Test connectivity from monitoring host
curl http://<container-ip>:8080/actuator/prometheus

# Check firewall on containers
ssh root@proxmox-server
pct exec 200 -- iptables -L -n -v
```

### Grafana Dashboard Shows No Data

```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets | jq

# Check if data is being collected
curl http://localhost:9090/api/v1/query?query=up

# Check Grafana datasource
curl -u admin:password http://localhost:3000/api/datasources
```

### Container Metrics Not Available

```bash
# Verify actuator is enabled
ssh root@proxmox-server
pct exec 200 -- curl http://localhost:8080/actuator/health
pct exec 200 -- curl http://localhost:8080/actuator/prometheus | head -50

# Check application logs
pct exec 200 -- journalctl -u spring-mvc-traditional -n 100
```

## Useful Queries

### Compare Response Times

```promql
histogram_quantile(0.95, 
  rate(http_server_requests_seconds_bucket{application=~"spring.*"}[5m])
)
```

### Compare Throughput

```promql
sum by (application) (
  rate(http_server_requests_seconds_count{application=~"spring.*"}[1m])
)
```

### Memory Efficiency

```promql
jvm_memory_used_bytes{application=~"spring.*", area="heap"} / 1024 / 1024
```

### Thread Comparison

```promql
jvm_threads_live_threads{application=~"spring.*"}
```

## Maintenance

### Backup Monitoring Data

```bash
# Backup Prometheus data
docker exec prometheus tar czf - /prometheus > prometheus-backup-$(date +%Y%m%d).tar.gz

# Backup Grafana data
docker exec grafana tar czf - /var/lib/grafana > grafana-backup-$(date +%Y%m%d).tar.gz
```

### Update Containers

```bash
# Update Prometheus
docker pull prom/prometheus:latest
docker stop prometheus
docker rm prometheus
# Re-run docker run command

# Update Grafana
docker pull grafana/grafana:latest
docker stop grafana
docker rm grafana
# Re-run docker run command
```

## Performance Comparison Dashboard

The included dashboard `spring-performance-comparison.json` shows:

1. **Request Rate** - Throughput comparison
2. **Response Time (p95)** - Latency comparison
3. **JVM Memory** - Heap usage patterns
4. **Thread Count** - Thread utilization
5. **CPU Usage** - Process and system CPU
6. **HTTP Errors** - Error rate tracking
7. **GC Activity** - Garbage collection frequency
8. **GC Pause Time** - GC impact on performance

## Advanced: Node Exporter (Optional)

For system-level metrics from LXC containers:

```bash
# On each LXC container
ssh root@proxmox-server

# Download and install node_exporter
for CTID in 200 201 202; do
  pct exec $CTID -- bash << 'EOF'
    wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
    tar xvfz node_exporter-1.7.0.linux-amd64.tar.gz
    sudo cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
    
    # Create systemd service
    cat > /etc/systemd/system/node_exporter.service << 'EOFSERVICE'
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/node_exporter
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOFSERVICE
    
    systemctl daemon-reload
    systemctl enable node_exporter
    systemctl start node_exporter
EOF
done
```

Then add to prometheus.yml:
```yaml
  - job_name: 'node-exporter'
    static_configs:
      - targets:
        - '<container-200-ip>:9100'
        - '<container-201-ip>:9100'
        - '<container-202-ip>:9100'
```

## Next Steps

1. ✅ Set up monitoring host with Docker
2. ✅ Configure GitHub Secrets
3. ✅ Run deployment workflow or manual deployment
4. ✅ Access Grafana and verify dashboards
5. ✅ Configure alerting (optional)
6. ✅ Set up backups for monitoring data

## Security Recommendations

1. **Change Grafana password** - Use strong password in secret
2. **Enable HTTPS** - Use reverse proxy (nginx/traefik)
3. **Restrict access** - Firewall rules for ports 3000 and 9090
4. **Read-only Prometheus** - Configure datasource as read-only
5. **Regular updates** - Keep Docker images updated
