# Self-Hosted Runner Setup for GHCR Image Building

This guide provides step-by-step instructions for setting up a self-hosted GitHub Actions runner that can build and push Docker images to GitHub Container Registry (ghcr.io) using Jib.

## Overview

Your workflows use `runs-on: self-hosted`, which means GitHub Actions will execute jobs on your own infrastructure instead of GitHub-hosted runners. For building and pushing Docker images with Jib to GHCR, your self-hosted runner needs specific prerequisites and configuration.

## Quick Start Checklist

- [ ] Self-hosted runner installed and registered with GitHub
- [ ] Java 21 installed
- [ ] Maven 3.6+ installed
- [ ] Docker installed and running
- [ ] Runner user added to `docker` group
- [ ] Workflow permissions configured in repository settings
- [ ] Test workflow run successful

## Prerequisites

### System Requirements

- **Operating System**: Linux (Ubuntu 20.04/22.04 recommended)
- **CPU**: 2+ cores recommended
- **RAM**: 4GB minimum, 8GB recommended
- **Disk Space**: 20GB+ free space for builds and images
- **Network**: Stable internet connection, access to ghcr.io

### Software Requirements

- **Java 21** (OpenJDK or Eclipse Temurin)
- **Maven 3.6+**
- **Docker 20.10+**
- **Git 2.x**

## Step 1: Install Self-Hosted Runner

### 1.1 Register the Runner

1. Go to your GitHub repository
2. Navigate to **Settings** → **Actions** → **Runners**
3. Click **New self-hosted runner**
4. Select your operating system (Linux)
5. Follow the displayed commands:

```bash
# Create a directory for the runner
mkdir actions-runner && cd actions-runner

# Download the runner package (version may differ)
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz

# Extract the installer
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz

# Configure the runner (replace with your repository URL and token from GitHub)
./config.sh --url https://github.com/YOUR_USERNAME/YOUR_REPOSITORY --token YOUR_TOKEN_FROM_GITHUB

# Run the runner
./run.sh
```

### 1.2 Run as a Service (Recommended)

To keep the runner running in the background:

```bash
# Install the service
sudo ./svc.sh install

# Start the service
sudo ./svc.sh start

# Check status
sudo ./svc.sh status
```

## Step 2: Install Java 21

### Ubuntu/Debian

```bash
# Update package list
sudo apt update

# Install Java 21 (OpenJDK)
sudo apt install -y openjdk-21-jdk

# Verify installation
java -version
# Should show: openjdk version "21..."

# Set JAVA_HOME (add to ~/.bashrc or /etc/environment)
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
```

### Alternative: Eclipse Temurin

```bash
# Add Eclipse Temurin repository
wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo apt-key add -
echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | sudo tee /etc/apt/sources.list.d/adoptium.list

# Install
sudo apt update
sudo apt install -y temurin-21-jdk

# Verify
java -version
```

## Step 3: Install Maven

```bash
# Install Maven
sudo apt update
sudo apt install -y maven

# Verify installation
mvn -version
# Should show Maven 3.6.x or higher

# Alternative: Install latest Maven manually
# wget https://dlcdn.apache.org/maven/maven-3/3.9.6/binaries/apache-maven-3.9.6-bin.tar.gz
# sudo tar xzf apache-maven-3.9.6-bin.tar.gz -C /opt
# sudo ln -s /opt/apache-maven-3.9.6 /opt/maven
# export PATH=/opt/maven/bin:$PATH
```

## Step 4: Install Docker

### 4.1 Install Docker Engine

```bash
# Install Docker using the convenience script
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Verify installation
docker --version
# Should show: Docker version 20.x or higher

# Start Docker service
sudo systemctl enable docker
sudo systemctl start docker

# Check Docker is running
sudo systemctl status docker
```

### 4.2 Configure Docker Permissions

**CRITICAL**: The runner user must have permission to use Docker!

```bash
# Add the runner user to the docker group
# Replace 'runner' with your actual runner username
sudo usermod -aG docker $USER

# If runner runs as a different user (common setup)
# Find the runner username first:
ps aux | grep "Runner.Listener"
# Then add that user to docker group:
sudo usermod -aG docker <runner-username>

# Apply group changes (requires logout/login or service restart)
# Option 1: Restart the runner service
sudo ./svc.sh stop
sudo ./svc.sh start

# Option 2: Or use newgrp (for current session only)
newgrp docker

# Verify Docker works without sudo
docker ps
# Should work without permission denied
```

### 4.3 Test Docker Installation

```bash
# Test Docker without sudo
docker run hello-world

# Test Docker build capability
docker build --help

# Check Docker daemon is accessible
docker info
```

## Step 5: Configure Workflow Permissions

The workflow uses `GITHUB_TOKEN` which is automatically provided, but you need to ensure proper permissions:

### 5.1 Repository Settings

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Actions** → **General**
3. Scroll to **Workflow permissions**
4. Select **"Read and write permissions"**
5. Check **"Allow GitHub Actions to create and approve pull requests"** (optional)
6. Click **Save**

### 5.2 Verify Workflow Permissions

Check that your workflow has the correct permissions (already configured in `ci.yml`):

```yaml
permissions:
  contents: read
  packages: write  # Required for pushing to GHCR
```

## Step 6: Verify Setup

### 6.1 Test Maven Build

```bash
# Clone your repository (replace with your actual repository URL)
git clone https://github.com/YOUR_USERNAME/YOUR_REPOSITORY.git
cd YOUR_REPOSITORY

# Test Maven build
mvn clean package -DskipTests

# Test with tests
mvn clean package
```

### 6.2 Test Docker with Jib

```bash
# Build Docker images locally
mvn clean package jib:dockerBuild

# Verify images were created
docker images | grep spring-performance

# Test running an image
docker run -d -p 8080:8080 spring-performance/spring-mvc-traditional:latest
curl http://localhost:8080/actuator/health
docker stop $(docker ps -q --filter ancestor=spring-performance/spring-mvc-traditional:latest)
```

### 6.3 Test GHCR Authentication

The workflow uses `docker/login-action@v3` which handles authentication, but you can test manually:

```bash
# The GITHUB_TOKEN is automatically available in workflows
# For manual testing, you can use a Personal Access Token:

# Create a PAT with write:packages scope (see GHCR-AUTHENTICATION.md)
# Then login:
echo YOUR_PAT | docker login ghcr.io -u YOUR_USERNAME --password-stdin

# Test push (this will push to your registry!)
docker tag spring-performance/spring-mvc-traditional:latest ghcr.io/wingadium1/spring-java-thread-performance/spring-mvc-traditional:test
docker push ghcr.io/wingadium1/spring-java-thread-performance/spring-mvc-traditional:test

# Cleanup test image
docker rmi ghcr.io/wingadium1/spring-java-thread-performance/spring-mvc-traditional:test
```

### 6.4 Trigger a Test Workflow

```bash
# Make a test commit to trigger the workflow
git checkout -b test-runner-setup
git commit --allow-empty -m "Test self-hosted runner setup"
git push origin test-runner-setup

# Watch the workflow execution
# Go to: https://github.com/YOUR_USERNAME/YOUR_REPOSITORY/actions
```

## How It Works with Self-Hosted Runners

### GITHUB_TOKEN on Self-Hosted Runners

- `GITHUB_TOKEN` is automatically provided by GitHub Actions
- Works identically on self-hosted and GitHub-hosted runners
- No manual configuration needed
- Token has `packages: write` permission when configured in repository settings

### Docker Login Action

The workflow uses `docker/login-action@v3`:

```yaml
- name: Log in to GitHub Container Registry
  uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

This action:
1. Runs on your self-hosted runner
2. Uses Docker CLI installed on your runner
3. Creates `~/.docker/config.json` with credentials
4. Jib uses these credentials automatically

### Jib with Docker

Jib can work in two modes:
1. **jib:build** - Pushes directly to registry (doesn't need Docker)
2. **jib:dockerBuild** - Builds to local Docker daemon

The workflow uses `jib:build` with authentication:

```bash
mvn -pl ${module} jib:build \
  -Djib.to.image="ghcr.io/..." \
  -Djib.to.auth.username="..." \
  -Djib.to.auth.password="${GITHUB_TOKEN}"  # Password provided via environment variable
```

## Troubleshooting

### Issue: "permission denied" when running Docker

**Cause**: Runner user not in docker group or changes not applied.

**Solution**:
```bash
# Add user to docker group
sudo usermod -aG docker $(whoami)

# Restart runner service
cd ~/actions-runner
sudo ./svc.sh stop
sudo ./svc.sh start

# Or reboot the machine
sudo reboot
```

### Issue: "docker: command not found"

**Cause**: Docker not installed or not in PATH.

**Solution**:
```bash
# Check if Docker is installed
which docker

# If not found, install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add to PATH if needed
export PATH=/usr/bin:$PATH
```

### Issue: "Cannot connect to the Docker daemon"

**Cause**: Docker daemon not running.

**Solution**:
```bash
# Start Docker service
sudo systemctl start docker

# Enable on boot
sudo systemctl enable docker

# Check status
sudo systemctl status docker
```

### Issue: "insufficient_scope: authorization failed"

**Cause**: Workflow doesn't have packages:write permission.

**Solution**:
1. Go to repository **Settings** → **Actions** → **General**
2. Set **Workflow permissions** to "Read and write permissions"
3. Re-run the workflow

### Issue: "denied: permission_denied: write_package"

**Cause**: GITHUB_TOKEN doesn't have permission to push packages.

**Solution**:
- Check workflow permissions in repository settings
- Ensure `packages: write` is in workflow job permissions
- Verify the workflow YAML has the correct permissions section

### Issue: Workflow stuck or not picking up jobs

**Cause**: Runner offline or not connected.

**Solution**:
```bash
# Check runner service status
cd ~/actions-runner
sudo ./svc.sh status

# View runner logs
journalctl -u actions.runner.* -f

# Restart runner
sudo ./svc.sh restart
```

### Issue: "Out of disk space"

**Cause**: Docker images and build artifacts consuming disk space.

**Solution**:
```bash
# Clean up Docker
docker system prune -a -f

# Remove old images
docker image prune -a -f

# Check disk usage
df -h

# Clean Maven cache
rm -rf ~/.m2/repository
```

### Issue: Java version mismatch

**Cause**: Wrong Java version installed or JAVA_HOME incorrect.

**Solution**:
```bash
# Check Java version
java -version

# Should be Java 21
# If not, install Java 21 (see Step 2)

# Set JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
echo 'export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64' >> ~/.bashrc
```

## Maintenance

### Regular Maintenance Tasks

```bash
# Update runner (when new version available)
cd ~/actions-runner
sudo ./svc.sh stop
./config.sh remove --token YOUR_REMOVAL_TOKEN
# Download new version and reconfigure
sudo ./svc.sh install
sudo ./svc.sh start

# Clean Docker resources weekly
docker system prune -a -f

# Update system packages monthly
sudo apt update && sudo apt upgrade -y

# Monitor disk space
df -h
du -sh ~/.m2/repository
```

### Monitoring Runner Health

```bash
# Check runner service
sudo ./svc.sh status

# View runner logs
journalctl -u actions.runner.* -f

# Monitor system resources
top
htop  # if installed

# Check Docker stats
docker stats

# Monitor disk usage
watch -n 5 df -h
```

## Security Best Practices

1. **Isolate the Runner**: Run on a dedicated machine or VM
2. **Limit Network Access**: Use firewall rules to restrict access
3. **Regular Updates**: Keep OS, Docker, Java, and Maven updated
4. **Runner User**: Use a dedicated user account for the runner
5. **No Root**: Never run the runner as root
6. **Secrets**: Never log or expose GITHUB_TOKEN or other secrets
7. **Clean Workspace**: Use `actions/checkout` with clean: true
8. **Monitor Logs**: Regularly check runner and Docker logs

## Alternative: Using Docker-in-Docker

If you can't add the runner user to the docker group, you can use Docker-in-Docker:

```yaml
steps:
  - uses: actions/checkout@v6
  
  - name: Set up Docker Buildx
    uses: docker/setup-buildx-action@v3
  
  # Rest of your workflow...
```

However, this is **not recommended** as Jib works best with direct Docker access.

## Related Documentation

- [GHCR Authentication Guide](GHCR-AUTHENTICATION.md) - Complete GHCR authentication guide
- [GHCR Quickstart](GHCR-QUICKSTART.md) - Quick reference for GHCR setup
- [Workflows README](workflows/README.md) - All workflows overview
- [GitHub Actions Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Docker Post-Installation Steps](https://docs.docker.com/engine/install/linux-postinstall/)

## Summary

For self-hosted runners to build and push Docker images to GHCR:

1. ✅ Install and register self-hosted runner
2. ✅ Install Java 21, Maven, and Docker
3. ✅ Add runner user to docker group
4. ✅ Configure workflow permissions in repository settings
5. ✅ Test the setup with a workflow run

The workflow uses `GITHUB_TOKEN` automatically - no manual token configuration needed! 🎉
