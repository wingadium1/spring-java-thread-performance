# Proxmox Deployment Setup Guide

## Quick Setup Checklist

Follow these steps to set up automated deployment to your Proxmox server:

### 1. Prepare Proxmox Server

#### Option A: VM Deployment (Systemd Services)

```bash
# SSH into your Proxmox VM
ssh user@your-proxmox-server

# Install Java 21
sudo apt update
sudo apt install -y openjdk-21-jdk

# Create application directory
sudo mkdir -p /opt/spring-performance
sudo chown $USER:$USER /opt/spring-performance

# Verify Java installation
java -version  # Should show Java 21
```

#### Option B: Docker Deployment

```bash
# SSH into your Proxmox VM
ssh user@your-proxmox-server

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt install -y docker-compose

# Create application directory
sudo mkdir -p /opt/spring-performance
sudo chown $USER:$USER /opt/spring-performance

# Verify Docker installation
docker --version
docker-compose --version
```

### 2. Set up SSH Key for GitHub Actions

```bash
# On your local machine or CI server
ssh-keygen -t ed25519 -C "github-actions-proxmox-deploy" -f ~/.ssh/proxmox_deploy

# Copy the public key to Proxmox server
ssh-copy-id -i ~/.ssh/proxmox_deploy.pub user@your-proxmox-server

# Test the connection
ssh -i ~/.ssh/proxmox_deploy user@your-proxmox-server "echo 'SSH connection successful'"

# Display the private key (you'll need this for GitHub Secrets)
cat ~/.ssh/proxmox_deploy
```

### 3. Configure GitHub Secrets

1. Go to your GitHub repository: https://github.com/wingadium1/spring-java-thread-performance
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** and add these secrets:

| Secret Name | Value | Example |
|-------------|-------|---------|
| `PROXMOX_HOST` | Your Proxmox server IP or hostname | `192.168.1.100` |
| `PROXMOX_USER` | SSH username | `ubuntu` or `deploy` |
| `PROXMOX_SSH_KEY` | Private key content from step 2 | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
| `PROXMOX_DEPLOY_METHOD` | Deployment method | `systemd` (default), `docker`, or `docker-compose` |

**Important**: 
- Copy the entire private key including the header and footer lines
- The key should be pasted as-is without any modifications

### 4. Set up Self-Hosted Runner

1. Go to **Settings** → **Actions** → **Runners** → **New self-hosted runner**
2. Choose your operating system (Linux recommended)
3. Follow the installation commands provided by GitHub:

```bash
# Example installation (use the actual commands from GitHub)
mkdir actions-runner && cd actions-runner
curl -o actions-runner-linux-x64-2.XXX.X.tar.gz -L https://github.com/actions/runner/releases/download/vX.XXX.X/actions-runner-linux-x64-2.XXX.X.tar.gz
tar xzf ./actions-runner-linux-x64-2.XXX.X.tar.gz

# Configure the runner (use the token provided by GitHub)
./config.sh --url https://github.com/wingadium1/spring-java-thread-performance --token YOUR_TOKEN

# Install as a service (optional but recommended)
sudo ./svc.sh install
sudo ./svc.sh start
```

4. Install required tools on the runner machine:

```bash
# Install Java 21
sudo apt update
sudo apt install -y openjdk-21-jdk

# Install Maven
sudo apt install -y maven

# Install Docker (if building Docker images)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $(whoami)

# Re-login or restart the runner service
sudo ./svc.sh restart
```

## Deployment Methods Explained

### Method 1: Systemd (Default - Recommended for Simple Deployments)

**How it works:**
- Copies JAR files to `/opt/spring-performance/`
- Installs systemd service files
- Manages applications as Linux services

**Pros:**
- Simple and reliable
- Easy to monitor with `systemctl status`
- Automatic restart on failure
- Native log management with journalctl

**Cons:**
- Requires manual Java installation
- Less portable than containers

**Set secret:** `PROXMOX_DEPLOY_METHOD=systemd` (or omit for default)

### Method 2: Docker (Recommended for Container Deployments)

**How it works:**
- Transfers Docker images as tar files
- Loads images on Proxmox
- Runs containers individually

**Pros:**
- Consistent environment
- Easy rollback
- No Java installation needed

**Cons:**
- Requires Docker on Proxmox
- Manual container management

**Set secret:** `PROXMOX_DEPLOY_METHOD=docker`

### Method 3: Docker Compose (Recommended for Full Stack)

**How it works:**
- Transfers Docker images
- Uses docker-compose.yml for orchestration
- Manages all services together including monitoring

**Pros:**
- Complete stack deployment
- Includes Prometheus and Grafana
- Easy to scale and manage
- Network isolation

**Cons:**
- Requires Docker and Docker Compose
- More complex setup

**Set secret:** `PROXMOX_DEPLOY_METHOD=docker-compose`

## Verification

After setup, verify the workflow:

1. Push a commit to `main` or `develop` branch
2. Go to **Actions** tab in GitHub
3. Watch the workflow execute
4. Check logs for any errors

You can also manually trigger the workflow:
1. Go to **Actions** → **Build and Deploy to Proxmox**
2. Click **Run workflow**
3. Select branch and click **Run workflow**

## Accessing Deployed Applications

After successful deployment, access your applications:

```bash
# Spring MVC Traditional
curl http://your-proxmox-server:8080/api/info
curl http://your-proxmox-server:8080/actuator/health

# Spring Virtual Threads
curl http://your-proxmox-server:8081/api/info
curl http://your-proxmox-server:8081/actuator/health

# Spring WebFlux
curl http://your-proxmox-server:8082/api/info
curl http://your-proxmox-server:8082/actuator/health
```

## Troubleshooting

### SSH Connection Failed

```bash
# Test SSH connection manually
ssh -i ~/.ssh/proxmox_deploy user@your-proxmox-server

# Check if key is correct format
head -1 ~/.ssh/proxmox_deploy  # Should show BEGIN OPENSSH PRIVATE KEY or BEGIN RSA PRIVATE KEY

# Verify key permissions
chmod 600 ~/.ssh/proxmox_deploy
```

### Build Failed on Self-Hosted Runner

```bash
# Check Java version
java -version  # Must be 21

# Check Maven is installed
mvn -version

# Check Docker is running (if building images)
docker ps
```

### Deployment Failed

```bash
# Check if directory exists
ssh user@proxmox-server "ls -la /opt/spring-performance"

# Check systemd service status
ssh user@proxmox-server "sudo systemctl status spring-mvc-traditional"

# View service logs
ssh user@proxmox-server "sudo journalctl -u spring-mvc-traditional -n 50"

# Check Docker containers (if using Docker)
ssh user@proxmox-server "docker ps -a"
```

### Application Not Responding

```bash
# Check if port is listening
ssh user@proxmox-server "sudo netstat -tlnp | grep -E '8080|8081|8082'"

# Check firewall rules
ssh user@proxmox-server "sudo ufw status"

# If needed, open ports
ssh user@proxmox-server "sudo ufw allow 8080/tcp && sudo ufw allow 8081/tcp && sudo ufw allow 8082/tcp"
```

## Security Recommendations

1. **Use a dedicated SSH key** - Don't reuse personal SSH keys
2. **Limit SSH key permissions** - Consider using `authorized_keys` options:
   ```
   command="/usr/local/bin/deploy-script.sh",no-port-forwarding,no-X11-forwarding,no-agent-forwarding ssh-ed25519 AAAA...
   ```
3. **Create a dedicated deployment user** - Don't use root or personal accounts
4. **Use sudo carefully** - Grant only necessary permissions via sudoers
5. **Monitor deployments** - Set up notifications for deployment failures
6. **Rotate credentials** - Regularly update SSH keys and secrets

## Next Steps

After successful deployment:

1. **Set up monitoring** - Access Grafana at `http://your-proxmox-server:3000`
2. **Configure load balancer** - Set up Nginx or HAProxy
3. **Set up SSL/TLS** - Use Let's Encrypt for HTTPS
4. **Configure backups** - Set up automated backups of application data
5. **Set up logging** - Configure centralized logging with ELK or similar
