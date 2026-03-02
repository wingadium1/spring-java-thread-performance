# GitHub Actions Workflows

## Overview

This repository uses GitHub Actions with self-hosted runners to build and deploy Spring Boot applications using multiple deployment strategies.

## Available Workflows

### 1. CI - Build and Test (`ci.yml`)

Continuous integration for main development flows.

**Actions:** Build with Maven, Run tests, publish Docker images to GHCR on `main`/`develop` push

**Triggers:** Push to `main`/`develop`, Pull Requests, Manual

### 2. Deploy to Proxmox LXC Containers (`deploy-proxmox-lxc.yml`)

Creates and manages LXC containers directly on Proxmox using the Proxmox API:

**Features:**
- Automatic container creation via Proxmox API
- Each app gets its own isolated container
- Systemd service management
- Resource allocation per container

**Triggers:** After successful CI on `main`/`develop`, Manual

**Documentation:** See [PROXMOX-LXC-GUIDE.md](../PROXMOX-LXC-GUIDE.md)

### 3. Deploy to microk8s (`deploy-microk8s.yml`)

Deploys to a microk8s cluster running on a Proxmox VM:

**Features:**
- Kubernetes-native deployment
- Uses existing Kubernetes manifests
- Automatic image import to microk8s
- Service scaling and self-healing

**Triggers:** After successful CI on `main`/`develop`, Manual

**Documentation:** See [MICROK8S-GUIDE.md](../MICROK8S-GUIDE.md)

## CI to Deploy Flow

- CI (`ci.yml`) runs build + unit tests.
- CI publishes container images to GHCR (`ghcr.io/<owner>/spring-java-thread-performance`) on `main`/`develop` pushes.
- On successful CI for `main`/`develop`, GitHub automatically triggers deploy workflows.
- Deployment target is selected by `PROXMOX_DEPLOY_METHOD` secret:
	- `micro-k8s` → run `deploy-microk8s.yml`
	- `proxmox-lxc` → run `deploy-proxmox-lxc.yml`

## Choosing a Deployment Method

| Method | Complexity | Overhead | Isolation | Monitoring | Best For |
|--------|------------|----------|-----------|------------|----------|
| **LXC Containers** | Medium | Very Low | OS-level | External | Multiple isolated apps ⭐ |
| **microk8s** | Medium | Medium | Pod-level | Built-in | K8s learning/testing |

⭐ **Recommended**: LXC with external Prometheus/Grafana monitoring

## GitHub Container Registry (GHCR) Authentication

The CI workflow automatically authenticates with GitHub Container Registry (ghcr.io) to push Docker images using Jib.

**Default Configuration**: Uses `GITHUB_TOKEN` (automatically provided, no setup required)

📘 **For detailed authentication setup and troubleshooting, see [GHCR-AUTHENTICATION.md](../GHCR-AUTHENTICATION.md)**

Key points:
- ✅ `docker/login-action@v3` is already configured in `ci.yml`
- ✅ Uses `GITHUB_TOKEN` with `packages: write` permission
- ✅ Works out of the box for pushing to `ghcr.io`
- 📦 Images are pushed to: `ghcr.io/wingadium1/spring-java-thread-performance/{module-name}`

## Required GitHub Secrets

Configure secrets based on your chosen deployment method:

### Deployment selector

| Secret Name | Description | Allowed values |
|-------------|-------------|----------------|
| `PROXMOX_DEPLOY_METHOD` | Selects which deploy workflow will execute | `micro-k8s` or `proxmox-lxc` |

### For LXC Container Deployment (`deploy-proxmox-lxc.yml`)

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `PROXMOX_API_HOST` | Proxmox server IP/hostname | `192.168.1.100` |
| `PROXMOX_API_TOKEN_ID` | API Token ID | `root@pam!github-actions` |
| `PROXMOX_API_SECRET` | API Token Secret | `xxxxxxxx-xxxx-xxxx...` |
| `PROXMOX_NODE` | Proxmox node name | `pve` or `proxmox1` |
| `PROXMOX_SSH_KEY` | SSH private key for root | Contents of private key file |

### For microk8s Deployment (`deploy-microk8s.yml`)

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `MICROK8S_HOST` | VM IP with microk8s | `192.168.1.150` |
| `MICROK8S_USER` | SSH username | `ubuntu` |
| `MICROK8S_SSH_KEY` | SSH private key | Contents of private key file |


### Setting up Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret listed above with the appropriate values

### SSH Key Setup

To generate an SSH key pair for deployment:

```bash
# Generate SSH key pair
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/proxmox_deploy

# Copy public key to Proxmox server
ssh-copy-id -i ~/.ssh/proxmox_deploy.pub user@proxmox-server

# Copy the private key content to PROXMOX_SSH_KEY secret
cat ~/.ssh/proxmox_deploy
```

## Self-Hosted Runner Setup

This workflow uses `runs-on: self-hosted` to execute on your own infrastructure.

📘 **Complete Self-Hosted Runner Setup Guide**: See [SELF-HOSTED-RUNNER-SETUP.md](../SELF-HOSTED-RUNNER-SETUP.md) for detailed instructions on setting up a runner for Docker image building with GHCR.

### Quick Setup Summary

1. Go to your GitHub repository
2. Navigate to **Settings** → **Actions** → **Runners**
3. Click **New self-hosted runner**
4. Follow the instructions to download and configure the runner

### Runner Requirements

The self-hosted runner should have:
- **Java 21** (OpenJDK or Temurin)
- **Maven 3.6+**
- **Docker** (if building Docker images)
- **SSH client**
- Sufficient disk space for build artifacts
- Network access to Proxmox server

### Installing Prerequisites on Runner

```bash
# Install Java 21
sudo apt update
sudo apt install -y openjdk-21-jdk

# Install Maven
sudo apt install -y maven

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# IMPORTANT: Restart runner service to apply docker group changes
cd ~/actions-runner
sudo ./svc.sh stop
sudo ./svc.sh start

# Verify installations
java -version
mvn -version
docker --version
docker ps  # Should work without sudo
```

> **Important for GHCR**: The runner user MUST be in the `docker` group for the workflow to build and push images. See the complete guide for troubleshooting.

## Deployment Methods

The workflow supports three deployment methods (configured via `PROXMOX_DEPLOY_METHOD` secret):

### 1. Systemd Services (default)

Deploys JAR files and manages them as systemd services.

- Copies JAR files to `/opt/spring-performance/`
- Installs systemd service files
- Restarts services
- Best for: Simple VM deployments

### 2. Docker

Deploys as Docker containers managed individually.

- Transfers Docker image tar files
- Loads images on Proxmox
- Runs containers with `docker run`
- Best for: Container-based deployments without orchestration

### 3. Docker Compose

Deploys using docker-compose for orchestration.

- Transfers Docker images and docker-compose.yml
- Uses docker-compose to manage all services
- Includes Prometheus and Grafana
- Best for: Complete stack deployment with monitoring

## Proxmox Server Preparation

### For Systemd Deployment

```bash
# Create application user
sudo useradd -r -s /bin/false springapp

# Create application directory
sudo mkdir -p /opt/spring-performance
sudo chown $USER:$USER /opt/spring-performance

# Install Java 21
sudo apt update
sudo apt install -y openjdk-21-jdk
```

### For Docker Deployment

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt install -y docker-compose

# Create application directory
sudo mkdir -p /opt/spring-performance
sudo chown $USER:$USER /opt/spring-performance
```

## Workflow Execution

### Automatic Execution

The workflow runs automatically on:
- Push to `main` or `develop` branches
- Pull requests targeting these branches

### Manual Execution

1. Go to **Actions** tab in GitHub
2. Select **Build and Deploy to Proxmox** workflow
3. Click **Run workflow**
4. Select the branch
5. Click **Run workflow** button

## Troubleshooting

### SSH Connection Issues

```bash
# Test SSH connection
ssh -i ~/.ssh/proxmox_key user@proxmox-host "echo 'Connection successful'"

# Check SSH key permissions
chmod 600 ~/.ssh/proxmox_key
```

### Build Failures

```bash
# Test local build
mvn clean package

# Check Java version
java -version  # Should be 21

# Check Maven version
mvn -version
```

### Deployment Failures

```bash
# Check systemd service status
ssh user@proxmox-host "sudo systemctl status spring-mvc-traditional"

# View service logs
ssh user@proxmox-host "sudo journalctl -u spring-mvc-traditional -n 50"

# Check Docker containers
ssh user@proxmox-host "docker ps -a"
```

## Security Best Practices

1. **SSH Keys**: Use dedicated SSH keys for CI/CD, not personal keys
2. **Limited Permissions**: Create a dedicated user with minimal permissions
3. **Secrets Rotation**: Regularly rotate SSH keys and update secrets
4. **Network Security**: Use firewall rules to restrict access
5. **Audit Logs**: Monitor deployment logs regularly
