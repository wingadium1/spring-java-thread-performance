# GitHub Secrets Template

Copy this template and fill in your actual values when configuring GitHub Secrets.

## Required Secrets

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
