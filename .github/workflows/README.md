# GitHub Actions Workflows

## Overview

This repository uses GitHub Actions with self-hosted runners to build and deploy Spring Boot applications to a Proxmox server.

## Workflows

### Build and Deploy to Proxmox (`build-and-deploy.yml`)

This workflow:
1. Builds all Spring Boot modules using Maven
2. Runs tests
3. Creates Docker images using Jib
4. Deploys to Proxmox server using SSH

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches
- Manual workflow dispatch

## Required GitHub Secrets

To use this workflow, configure the following secrets in your GitHub repository settings (Settings → Secrets and variables → Actions):

### Proxmox Server Authentication

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `PROXMOX_HOST` | IP address or hostname of Proxmox server | `192.168.1.100` or `proxmox.example.com` |
| `PROXMOX_USER` | SSH username for Proxmox server | `deploy` or `ubuntu` |
| `PROXMOX_SSH_KEY` | Private SSH key for authentication | Contents of your private key file |
| `PROXMOX_DEPLOY_METHOD` | Deployment method (optional) | `systemd`, `docker`, or `docker-compose` |

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

### Setting up a Self-Hosted Runner

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

# Verify installations
java -version
mvn -version
docker --version
```

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
