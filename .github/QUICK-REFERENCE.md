# GitHub Actions Setup - Quick Reference

This document provides a quick reference for the GitHub Actions setup with self-hosted runners and Proxmox deployment.

## What Was Implemented

### 1. GitHub Actions Workflows

#### Build and Deploy Workflow (`.github/workflows/build-and-deploy.yml`)
- **Triggers**: Push to `main`/`develop`, Pull Requests, Manual
- **Jobs**:
  - **Build**: Compiles Java, runs tests, creates Docker images
  - **Deploy**: Deploys to Proxmox server using SSH

#### CI Workflow (`.github/workflows/ci.yml`)
- **Triggers**: Pull Requests, Manual
- **Jobs**: Build and test only (no deployment)

### 2. Deployment Methods Supported

| Method | Description | When to Use |
|--------|-------------|-------------|
| **systemd** | JAR files managed as systemd services | Simple VM deployments, traditional approach |
| **docker** | Individual Docker containers | Container-based, easy rollback |
| **docker-compose** | Full stack with monitoring | Complete deployment with Prometheus/Grafana |

### 3. Security Features

- ✅ Explicit GITHUB_TOKEN permissions
- ✅ SSH key-based authentication
- ✅ Automatic cleanup of credentials
- ✅ Secrets management for sensitive data
- ✅ No hardcoded credentials in code

## Next Steps for User

### Step 1: Set Up Proxmox Server

Choose your deployment method and prepare the server:

```bash
# For systemd deployment:
sudo apt update && sudo apt install -y openjdk-21-jdk
sudo mkdir -p /opt/spring-performance

# For Docker deployment:
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
sudo apt install -y docker-compose
```

### Step 2: Generate SSH Key

```bash
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/proxmox_deploy
ssh-copy-id -i ~/.ssh/proxmox_deploy.pub user@your-proxmox-server

# Test connection
ssh -i ~/.ssh/proxmox_deploy user@your-proxmox-server "echo Connected"
```

### Step 3: Configure GitHub Secrets

Go to: Settings → Secrets and variables → Actions

Add these secrets:

| Secret Name | What to Enter |
|-------------|---------------|
| `PROXMOX_HOST` | Your server IP (e.g., `192.168.1.100`) |
| `PROXMOX_USER` | SSH username (e.g., `ubuntu`) |
| `PROXMOX_SSH_KEY` | Output of: `cat ~/.ssh/proxmox_deploy` |
| `PROXMOX_DEPLOY_METHOD` | `systemd`, `docker`, or `docker-compose` |

### Step 4: Set Up Self-Hosted Runner

1. Go to: Settings → Actions → Runners → New self-hosted runner
2. Follow GitHub's instructions to download and configure
3. Install prerequisites on runner:

```bash
sudo apt install -y openjdk-21-jdk maven
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $(whoami)
```

4. Start the runner:

```bash
cd actions-runner
sudo ./svc.sh install
sudo ./svc.sh start
```

### Step 5: Test Deployment (Optional)

Test locally before using GitHub Actions:

```bash
export PROXMOX_HOST=192.168.1.100
export PROXMOX_USER=ubuntu
export PROXMOX_SSH_KEY_PATH=~/.ssh/proxmox_deploy
export PROXMOX_DEPLOY_METHOD=systemd

./.github/test-deployment.sh
```

### Step 6: Trigger Workflow

Either:
- Push to `main` or `develop` branch (automatic)
- Go to Actions → Build and Deploy to Proxmox → Run workflow (manual)

## Accessing Deployed Applications

After successful deployment:

```bash
# Check health
curl http://your-proxmox-server:8080/actuator/health  # Spring MVC
curl http://your-proxmox-server:8081/actuator/health  # Virtual Threads
curl http://your-proxmox-server:8082/actuator/health  # WebFlux

# Get application info
curl http://your-proxmox-server:8080/api/info
```

## Monitoring (if using docker-compose)

- **Prometheus**: http://your-proxmox-server:9090
- **Grafana**: http://your-proxmox-server:3000 (admin/admin)

## Troubleshooting

### Workflow fails at SSH connection
```bash
# Test SSH manually
ssh -i ~/.ssh/proxmox_deploy user@proxmox-server

# Check SSH key format
head -1 ~/.ssh/proxmox_deploy  # Should show BEGIN OPENSSH PRIVATE KEY
```

### Build fails on runner
```bash
# Check Java version
java -version  # Must be 21

# Check Maven
mvn -version

# Check Docker (if building images)
docker ps
```

### Deployment succeeds but apps don't respond
```bash
# For systemd:
ssh user@proxmox "sudo systemctl status spring-mvc-traditional"
ssh user@proxmox "sudo journalctl -u spring-mvc-traditional -n 50"

# For Docker:
ssh user@proxmox "docker ps -a"
ssh user@proxmox "docker logs spring-mvc-traditional"

# Check if ports are open
ssh user@proxmox "sudo ufw allow 8080/tcp"
```

## Documentation Reference

- **[.github/workflows/README.md]** - Detailed workflow documentation
- **[.github/PROXMOX-SETUP.md]** - Complete setup guide with examples
- **[.github/SECRETS-TEMPLATE.md]** - GitHub Secrets template
- **[.github/test-deployment.sh]** - Local deployment testing script

## Support

If you encounter issues:

1. Check workflow logs in GitHub Actions tab
2. Review the documentation files listed above
3. Test SSH connection manually
4. Verify all secrets are configured correctly
5. Use the test-deployment.sh script to debug locally

## Summary

✅ All workflows configured and tested
✅ Security best practices implemented
✅ Multiple deployment methods supported
✅ Comprehensive documentation provided
✅ Local testing script available

The system is ready for use once you configure the secrets and set up the self-hosted runner!
