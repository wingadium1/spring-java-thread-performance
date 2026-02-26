#!/bin/bash
# Setup script for monitoring host
# This script prepares the monitoring host with Docker and necessary tools

set -e

echo "========================================="
echo " Spring Performance Monitoring Setup"
echo "========================================="
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
  echo "⚠️  Warning: Running as root. It's recommended to run as a regular user."
fi

# Install Docker if not present
if ! command -v docker &> /dev/null; then
  echo "📦 Installing Docker..."
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sudo sh /tmp/get-docker.sh
  sudo usermod -aG docker $USER
  echo "✓ Docker installed"
  echo "⚠️  Please log out and log back in for docker group membership to take effect"
  echo "   Then run this script again."
  exit 0
else
  echo "✓ Docker is already installed"
  docker --version
fi

# Install required tools
echo ""
echo "📦 Installing required tools..."
if ! command -v jq &> /dev/null; then
  sudo apt-get update
  sudo apt-get install -y jq curl wget
  echo "✓ Tools installed"
else
  echo "✓ Required tools already installed"
fi

# Create monitoring directory structure
echo ""
echo "📁 Creating monitoring directory structure..."
mkdir -p ~/monitoring/{prometheus,grafana/provisioning/datasources,grafana/provisioning/dashboards,grafana/dashboards,alertmanager}
echo "✓ Directories created"

# Check if configuration files exist
echo ""
echo "📋 Checking for configuration files..."

if [ ! -f ~/monitoring/prometheus/prometheus.yml ]; then
  echo "⚠️  prometheus.yml not found in ~/monitoring/prometheus/"
  echo "   Please copy monitoring/prometheus-lxc.yml from the repository"
  echo "   and update container IPs"
else
  echo "✓ Prometheus configuration found"
fi

if [ ! -f ~/monitoring/grafana/provisioning/datasources/datasource.yml ]; then
  echo "⚠️  Grafana datasource not found"
  echo "   Please copy monitoring/grafana-datasource.yml from the repository"
else
  echo "✓ Grafana datasource configuration found"
fi

# Get container IPs from user
echo ""
echo "========================================="
echo " Container IP Configuration"
echo "========================================="
echo ""
echo "You need to provide the IPs of your LXC containers."
echo "Get them from Proxmox with: pct exec <CTID> -- hostname -I"
echo ""

read -p "Enter Container 200 (spring-mvc-traditional) IP: " CONTAINER_200_IP
read -p "Enter Container 201 (spring-virtual-threads) IP: " CONTAINER_201_IP
read -p "Enter Container 202 (spring-webflux) IP: " CONTAINER_202_IP

# Test connectivity to containers
echo ""
echo "🔍 Testing connectivity to containers..."

test_endpoint() {
  local ip=$1
  local port=$2
  local app=$3
  
  if curl -s -f --connect-timeout 5 "http://${ip}:${port}/actuator/health" > /dev/null 2>&1; then
    echo "✓ $app at $ip:$port is reachable"
    return 0
  else
    echo "✗ $app at $ip:$port is NOT reachable"
    return 1
  fi
}

test_endpoint "$CONTAINER_200_IP" "8080" "spring-mvc-traditional"
test_endpoint "$CONTAINER_201_IP" "8081" "spring-virtual-threads"
test_endpoint "$CONTAINER_202_IP" "8082" "spring-webflux"

# Deploy monitoring stack
echo ""
read -p "Do you want to deploy the monitoring stack now? (y/n): " DEPLOY_NOW

if [ "$DEPLOY_NOW" = "y" ] || [ "$DEPLOY_NOW" = "Y" ]; then
  echo ""
  echo "🚀 Deploying monitoring stack..."
  
  # Set Grafana password
  read -s -p "Enter Grafana admin password (minimum 8 characters): " GRAFANA_PASSWORD
  echo ""
  
  # Validate password length
  if [ ${#GRAFANA_PASSWORD} -lt 8 ]; then
    echo "❌ Error: Password must be at least 8 characters"
    exit 1
  fi
  
  # Create Docker network
  docker network create monitoring 2>/dev/null || echo "Network already exists"
  
  # Deploy Prometheus
  echo "Deploying Prometheus..."
  docker stop prometheus 2>/dev/null || true
  docker rm prometheus 2>/dev/null || true
  
  docker run -d \
    --name prometheus \
    --restart unless-stopped \
    --network monitoring \
    -p 9090:9090 \
    -v ~/monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro \
    prom/prometheus:latest \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/prometheus \
    --storage.tsdb.retention.time=30d \
    --web.enable-lifecycle
  
  echo "✓ Prometheus deployed"
  
  # Deploy Grafana
  echo "Deploying Grafana..."
  docker stop grafana 2>/dev/null || true
  docker rm grafana 2>/dev/null || true
  
  docker run -d \
    --name grafana \
    --restart unless-stopped \
    --network monitoring \
    -p 3000:3000 \
    -e "GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}" \
    -e "GF_USERS_ALLOW_SIGN_UP=false" \
    -v ~/monitoring/grafana/provisioning/datasources:/etc/grafana/provisioning/datasources:ro \
    -v ~/monitoring/grafana/provisioning/dashboards:/etc/grafana/provisioning/dashboards:ro \
    -v ~/monitoring/grafana/dashboards:/var/lib/grafana/dashboards:ro \
    grafana/grafana:latest
  
  echo "✓ Grafana deployed"
  
  # Wait for services
  echo ""
  echo "⏳ Waiting for services to start..."
  sleep 10
  
  # Check Prometheus
  if curl -s http://localhost:9090/-/ready | grep -q "Prometheus Server is Ready"; then
    echo "✓ Prometheus is ready: http://localhost:9090"
  else
    echo "⚠️  Prometheus may not be ready yet. Check with: docker logs prometheus"
  fi
  
  # Check Grafana
  if curl -s http://localhost:3000/api/health | grep -q "ok"; then
    echo "✓ Grafana is ready: http://localhost:3000"
    echo "  Username: admin"
    echo "  Password: (the password you just entered)"
  else
    echo "⚠️  Grafana may not be ready yet. Check with: docker logs grafana"
  fi
  
  echo ""
  echo "========================================="
  echo " Monitoring Stack Deployed Successfully!"
  echo "========================================="
  echo ""
  echo "Access Points:"
  echo "  Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
  echo "  Grafana:    http://$(hostname -I | awk '{print $1}'):3000"
  echo ""
  echo "Next Steps:"
  echo "1. Open Grafana in your browser"
  echo "2. Login with admin and the password you configured"
  echo "3. Import dashboards from monitoring/dashboards/"
  echo "4. Check Prometheus targets: http://localhost:9090/targets"
  echo ""
else
  echo ""
  echo "Skipping deployment. To deploy manually:"
  echo "  cd ~/monitoring"
  echo "  docker-compose up -d"
  echo ""
fi

echo "Setup complete! 🎉"
