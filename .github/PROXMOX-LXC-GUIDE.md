# Proxmox LXC Container Deployment Guide

This guide covers deploying Spring Boot applications directly to Proxmox LXC containers using the Proxmox API.

## Overview

This deployment method:
- Creates LXC containers directly on Proxmox using the API
- Deploys each Spring Boot application to its own container
- Uses systemd services within containers
- Provides isolation and resource management

## Prerequisites

### 1. Proxmox VE Server

You need a Proxmox VE 7.0+ server with:
- API access enabled
- LXC container templates available
- Sufficient resources (CPU, RAM, storage)

### 2. LXC Template

Download Ubuntu 22.04 LXC template on Proxmox:

```bash
# SSH to Proxmox host
ssh root@proxmox-server

# Download Ubuntu 22.04 template
pveam update
pveam available | grep ubuntu-22.04
pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst

# Verify template is available
pveam list local
```

### 3. Proxmox API Token

Create an API token for GitHub Actions:

```bash
# Option 1: Via Web UI
# 1. Go to Datacenter → Permissions → API Tokens
# 2. Click "Add"
# 3. User: root@pam (or your user)
# 4. Token ID: github-actions
# 5. Uncheck "Privilege Separation" (for full access)
# 6. Click "Add"
# 7. Copy the Token Secret (you won't see it again!)

# Option 2: Via CLI
pveum user token add root@pam github-actions --privsep 0

# Set permissions (if using privilege separation)
pveum acl modify / -user 'root@pam!github-actions' -role Administrator
```

## GitHub Secrets Configuration

Configure these secrets in GitHub (Settings → Secrets and variables → Actions):

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `PROXMOX_API_HOST` | Proxmox server IP or hostname | `192.168.1.100` |
| `PROXMOX_API_TOKEN_ID` | API Token ID | `root@pam!github-actions` |
| `PROXMOX_API_SECRET` | API Token Secret | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `PROXMOX_NODE` | Proxmox node name | `pve` or `proxmox1` |
| `PROXMOX_SSH_KEY` | SSH private key for root access | `-----BEGIN OPENSSH PRIVATE KEY-----...` |

### Get Proxmox Node Name

```bash
# SSH to Proxmox
ssh root@proxmox-server

# Get node name
pvesh get /nodes
# or
hostname
```

### Generate SSH Key for Proxmox

```bash
# Generate key
ssh-keygen -t ed25519 -C "github-actions-proxmox-lxc" -f ~/.ssh/proxmox_lxc

# Copy to Proxmox server
ssh-copy-id -i ~/.ssh/proxmox_lxc.pub root@proxmox-server

# Test connection
ssh -i ~/.ssh/proxmox_lxc root@proxmox-server "pvesh get /nodes"

# Copy private key for GitHub Secret
cat ~/.ssh/proxmox_lxc
```

## Container Configuration

The workflow creates three LXC containers:

| Application | Container ID | Port | Resources |
|-------------|--------------|------|-----------|
| spring-mvc-traditional | 200 | 8080 | 2GB RAM, 2 cores |
| spring-virtual-threads | 201 | 8081 | 2GB RAM, 2 cores |
| spring-webflux | 202 | 8082 | 2GB RAM, 2 cores |

You can customize these IDs in the workflow if needed.

## How the Workflow Works

1. **Build Phase**:
   - Builds Maven projects
   - Creates Docker images (for consistency)
   - Packages JAR files

2. **Container Creation**:
   - Calls Proxmox API to check if containers exist
   - Creates new LXC containers if needed
   - Starts stopped containers

3. **Deployment**:
   - Installs Java 21 in containers
   - Copies JAR files to containers
   - Creates systemd services
   - Starts applications

4. **Verification**:
   - Checks health endpoints
   - Displays service status

## Manual Container Creation

If you want to pre-create containers manually:

```bash
# SSH to Proxmox
ssh root@proxmox-server

# Create container for Spring MVC Traditional
pct create 200 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname spring-mvc-traditional \
  --memory 2048 \
  --cores 2 \
  --rootfs local-lvm:8 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --unprivileged 1 \
  --start 1

# Create container for Spring Virtual Threads
pct create 201 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname spring-virtual-threads \
  --memory 2048 \
  --cores 2 \
  --rootfs local-lvm:8 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --unprivileged 1 \
  --start 1

# Create container for Spring WebFlux
pct create 202 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname spring-webflux \
  --memory 2048 \
  --cores 2 \
  --rootfs local-lvm:8 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --unprivileged 1 \
  --start 1

# Wait for containers to start
sleep 10

# Install Java in each container
for CTID in 200 201 202; do
  pct exec $CTID -- apt-get update
  pct exec $CTID -- apt-get install -y openjdk-21-jdk curl
done

# Verify Java installation
pct exec 200 -- java -version
```

## Accessing Applications

### From Proxmox Host

```bash
# Get container IPs
pct exec 200 -- hostname -I
pct exec 201 -- hostname -I
pct exec 202 -- hostname -I

# Test applications
curl http://<container-200-ip>:8080/actuator/health
curl http://<container-201-ip>:8081/actuator/health
curl http://<container-202-ip>:8082/actuator/health
```

### From External Network

Configure port forwarding on Proxmox firewall:

```bash
# Add iptables rules for port forwarding
iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 8080 -j DNAT --to <container-200-ip>:8080
iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 8081 -j DNAT --to <container-201-ip>:8081
iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 8082 -j DNAT --to <container-202-ip>:8082

# Make rules persistent
apt-get install iptables-persistent
netfilter-persistent save
```

## Management Commands

### Start/Stop Containers

```bash
# Start all containers
pct start 200 201 202

# Stop all containers
pct stop 200 201 202

# Restart containers
pct reboot 200 201 202
```

### Check Container Status

```bash
# List all containers
pct list

# Get specific container status
pct status 200

# View container config
pct config 200
```

### View Application Logs

```bash
# View systemd logs inside container
pct exec 200 -- journalctl -u spring-mvc-traditional -n 50
pct exec 201 -- journalctl -u spring-virtual-threads -n 50
pct exec 202 -- journalctl -u spring-webflux -n 50

# Follow logs in real-time
pct exec 200 -- journalctl -u spring-mvc-traditional -f
```

### Execute Commands in Container

```bash
# Check Java process
pct exec 200 -- ps aux | grep java

# Check network
pct exec 200 -- netstat -tlnp

# Access container shell
pct enter 200
```

## Resource Management

### Adjust Container Resources

```bash
# Change memory allocation
pct set 200 -memory 4096

# Change CPU cores
pct set 200 -cores 4

# Change rootfs size
pct resize 200 rootfs +10G

# Apply changes (requires restart)
pct reboot 200
```

### Monitor Resource Usage

```bash
# Check container resource usage
pct exec 200 -- free -h
pct exec 200 -- df -h
pct exec 200 -- top -bn1 | head -20
```

## Backup and Restore

### Backup Containers

```bash
# Create backup
vzdump 200 --mode snapshot --storage local
vzdump 201 --mode snapshot --storage local
vzdump 202 --mode snapshot --storage local

# Backup all at once
vzdump 200 201 202 --mode snapshot --storage local
```

### Restore Container

```bash
# List backups
pvesm list local --content backup

# Restore from backup
pct restore 200 /var/lib/vz/dump/vzdump-lxc-200-2024_01_01-00_00_00.tar.zst
```

## Troubleshooting

### Container Won't Start

```bash
# Check container config
pct config 200

# Check Proxmox logs
tail -f /var/log/pve/tasks/active

# Try starting with debug
pct start 200 --debug
```

### Application Not Responding

```bash
# Check if service is running
pct exec 200 -- systemctl status spring-mvc-traditional

# Check if Java is installed
pct exec 200 -- java -version

# Check application logs
pct exec 200 -- journalctl -u spring-mvc-traditional -n 100

# Check network connectivity
pct exec 200 -- curl localhost:8080/actuator/health
```

### API Authentication Failed

```bash
# Test API token
curl -k -H "Authorization: PVEAPIToken=root@pam!github-actions=YOUR_SECRET" \
  https://proxmox-server:8006/api2/json/nodes

# Verify token permissions
pveum user token permissions root@pam github-actions
```

## Security Recommendations

1. **Use dedicated API token** - Don't use root password
2. **Enable privilege separation** - Create token with minimal required permissions
3. **Firewall rules** - Restrict API access to trusted IPs
4. **Container isolation** - Use unprivileged containers when possible
5. **Regular updates** - Keep Proxmox and container templates updated

## Cleanup

### Remove All Containers

```bash
# Stop and remove containers
pct stop 200 201 202
pct destroy 200 201 202

# Remove backups (optional)
rm /var/lib/vz/dump/vzdump-lxc-200-*.tar.zst
rm /var/lib/vz/dump/vzdump-lxc-201-*.tar.zst
rm /var/lib/vz/dump/vzdump-lxc-202-*.tar.zst
```

## Comparison: LXC vs VM vs Docker

| Feature | LXC Containers | VMs | Docker on VM |
|---------|----------------|-----|--------------|
| **Boot time** | <5 seconds | 30-60 seconds | <1 second |
| **Memory overhead** | ~10MB | ~500MB | ~50MB |
| **Isolation** | OS-level | Full hardware | Process-level |
| **Performance** | Near-native | 95-98% native | Near-native |
| **Management** | Proxmox API/CLI | Proxmox API/CLI | Docker CLI |
| **Best for** | Multiple isolated apps | Legacy apps, Windows | Microservices |

## Why Choose LXC Deployment?

✅ **Lightweight** - Much less overhead than VMs
✅ **Fast startup** - Containers boot in seconds
✅ **Native performance** - No virtualization overhead
✅ **Easy management** - Proxmox Web UI and API
✅ **Resource efficiency** - Run more apps on same hardware
✅ **Snapshots** - Quick backup and restore
✅ **Network isolation** - Each app has its own network stack
