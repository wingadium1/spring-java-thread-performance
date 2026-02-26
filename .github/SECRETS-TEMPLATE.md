# GitHub Secrets Template

Copy this template and fill in your actual values when configuring GitHub Secrets.

## Deployment Method Selection

Choose ONE of the following deployment methods:

1. **Proxmox VM** - Deploy to a VM using SSH (`build-and-deploy.yml`)
2. **Proxmox LXC** - Create containers on Proxmox using API (`deploy-proxmox-lxc.yml`)
3. **microk8s** - Deploy to Kubernetes on a VM (`deploy-microk8s.yml`)

## Secrets for Proxmox VM Deployment

### PROXMOX_HOST
**Description**: IP address or hostname of your Proxmox server
**Example**: `192.168.1.100` or `proxmox.yourdomain.com`
**Your Value**: 
```
<YOUR_PROXMOX_SERVER_IP_OR_HOSTNAME>
```

### PROXMOX_USER
**Description**: SSH username for connecting to Proxmox server
**Example**: `ubuntu`, `deploy`, or `admin`
**Your Value**:
```
<YOUR_SSH_USERNAME>
```

### PROXMOX_SSH_KEY
**Description**: Private SSH key for authentication (entire key content)
**Your Value**:
```
-----BEGIN OPENSSH PRIVATE KEY-----
<YOUR_PRIVATE_KEY_CONTENT_HERE>
-----END OPENSSH PRIVATE KEY-----
```

**To generate:**
```bash
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/proxmox_deploy
ssh-copy-id -i ~/.ssh/proxmox_deploy.pub user@proxmox-server
cat ~/.ssh/proxmox_deploy  # Copy this output
```

### PROXMOX_DEPLOY_METHOD (Optional)
**Description**: Deployment method to use
**Options**: `systemd` (default), `docker`, or `docker-compose`
**Your Value**:
```
systemd
```

## Secrets for Proxmox LXC Container Deployment

### PROXMOX_API_HOST
**Description**: Proxmox server IP or hostname
**Example**: `192.168.1.100` or `proxmox.example.com`
**Your Value**: 
```
<YOUR_PROXMOX_SERVER_IP>
```

### PROXMOX_API_TOKEN_ID
**Description**: Proxmox API Token ID (user@realm!token-name)
**Example**: `root@pam!github-actions`
**Your Value**:
```
<YOUR_API_TOKEN_ID>
```

**To create:**
```bash
# Via Proxmox Web UI: Datacenter → Permissions → API Tokens → Add
# Or via CLI:
ssh root@proxmox-server
pveum user token add root@pam github-actions --privsep 0
```

### PROXMOX_API_SECRET
**Description**: Proxmox API Token Secret (shown once during creation)
**Your Value**:
```
<YOUR_API_TOKEN_SECRET>
```

### PROXMOX_NODE
**Description**: Proxmox node name
**Example**: `pve`, `proxmox1`, `node1`
**Your Value**:
```
<YOUR_NODE_NAME>
```

**To find:**
```bash
ssh root@proxmox-server "hostname"
# or
ssh root@proxmox-server "pvesh get /nodes"
```

### PROXMOX_SSH_KEY (for LXC)
**Description**: SSH private key for root access to Proxmox
**Your Value**:
```
-----BEGIN OPENSSH PRIVATE KEY-----
<YOUR_PRIVATE_KEY_FOR_PROXMOX_ROOT>
-----END OPENSSH PRIVATE KEY-----
```

## Secrets for microk8s Deployment

### MICROK8S_HOST
**Description**: IP or hostname of VM with microk8s installed
**Example**: `192.168.1.150`
**Your Value**: 
```
<YOUR_MICROK8S_VM_IP>
```

### MICROK8S_USER
**Description**: SSH username for microk8s VM
**Example**: `ubuntu`
**Your Value**:
```
<YOUR_SSH_USERNAME>
```

### MICROK8S_SSH_KEY
**Description**: Private SSH key for microk8s VM
**Your Value**:
```
-----BEGIN OPENSSH PRIVATE KEY-----
<YOUR_PRIVATE_KEY_FOR_MICROK8S>
-----END OPENSSH PRIVATE KEY-----
```

**To generate:**
```bash
ssh-keygen -t ed25519 -C "github-actions-microk8s" -f ~/.ssh/microk8s_deploy
ssh-copy-id -i ~/.ssh/microk8s_deploy.pub user@microk8s-vm
cat ~/.ssh/microk8s_deploy  # Copy this output
```

## How to Add Secrets to GitHub

1. Go to your repository Settings → Secrets and variables → Actions
   - URL format: `https://github.com/YOUR_USERNAME/YOUR_REPO/settings/secrets/actions`
   - For this repo: `https://github.com/wingadium1/spring-java-thread-performance/settings/secrets/actions`
2. Click "New repository secret"
3. Enter the secret name (e.g., `PROXMOX_HOST`)
4. Paste the value
5. Click "Add secret"
6. Repeat for all required secrets

## Verification

After adding secrets, you can verify by:
1. Going to Actions tab
2. Manually triggering the "Build and Deploy to Proxmox" workflow
3. Checking the logs for any authentication errors
