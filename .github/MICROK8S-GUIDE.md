# microk8s Deployment Guide

This guide covers deploying Spring Boot applications to a microk8s cluster running on a Proxmox VM.

## Prerequisites

### 1. Proxmox VM with microk8s

Create a VM on Proxmox with:
- Ubuntu 22.04 LTS
- At least 4 CPU cores
- At least 8GB RAM
- At least 20GB disk space

### 2. Install microk8s on the VM

```bash
# SSH into the Proxmox VM
ssh user@proxmox-vm

# Install microk8s
sudo snap install microk8s --classic --channel=1.28/stable

# Add user to microk8s group
sudo usermod -a -G microk8s $USER
sudo chown -f -R $USER ~/.kube
newgrp microk8s

# Enable required addons
microk8s enable dns
microk8s enable registry
microk8s enable storage
microk8s enable ingress  # Optional

# Check status
microk8s status --wait-ready
```

### 3. Verify microk8s installation

```bash
# Check cluster status
microk8s kubectl get nodes

# Check system pods
microk8s kubectl get pods -A

# Verify registry is running
microk8s kubectl get pods -n container-registry
```

## GitHub Secrets Configuration

Add these secrets to your GitHub repository (Settings → Secrets and variables → Actions):

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `MICROK8S_HOST` | IP or hostname of VM with microk8s | `192.168.1.150` |
| `MICROK8S_USER` | SSH username for microk8s VM | `ubuntu` |
| `MICROK8S_SSH_KEY` | Private SSH key for authentication | `-----BEGIN OPENSSH PRIVATE KEY-----...` |

### Generate SSH Key

```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "github-actions-microk8s" -f ~/.ssh/microk8s_deploy

# Copy public key to microk8s VM
ssh-copy-id -i ~/.ssh/microk8s_deploy.pub user@microk8s-vm

# Test connection
ssh -i ~/.ssh/microk8s_deploy user@microk8s-vm "microk8s kubectl get nodes"

# Copy private key content for GitHub Secret
cat ~/.ssh/microk8s_deploy
```

## How the Workflow Works

The `deploy-microk8s.yml` workflow:

1. **Builds** Maven projects and Docker images
2. **Transfers** Docker images to microk8s VM
3. **Imports** images into microk8s using `microk8s ctr`
4. **Tags** images for local registry (localhost:32000)
5. **Deploys** using Kubernetes manifests
6. **Waits** for deployments to be ready
7. **Verifies** health of all services

## Manual Deployment to microk8s

If you want to deploy manually without GitHub Actions:

```bash
# 1. Build locally
mvn clean package
mvn jib:dockerBuild

# 2. Save Docker images
docker save spring-performance/spring-mvc-traditional:latest -o spring-mvc-traditional.tar
docker save spring-performance/spring-virtual-threads:latest -o spring-virtual-threads.tar
docker save spring-performance/spring-webflux:latest -o spring-webflux.tar

# 3. Transfer to microk8s VM
scp *.tar user@microk8s-vm:/tmp/

# 4. Import images on microk8s VM
ssh user@microk8s-vm
microk8s ctr image import /tmp/spring-mvc-traditional.tar
microk8s ctr image import /tmp/spring-virtual-threads.tar
microk8s ctr image import /tmp/spring-webflux.tar

# 5. Deploy Kubernetes manifests
cd ~/spring-performance-k8s
microk8s kubectl apply -f spring-mvc-traditional.yaml
microk8s kubectl apply -f spring-virtual-threads.yaml
microk8s kubectl apply -f spring-webflux.yaml

# 6. Check deployment status
microk8s kubectl get pods
microk8s kubectl get services
```

## Accessing Applications

### Option 1: Port Forwarding (from microk8s VM)

```bash
# Forward ports from services to VM
microk8s kubectl port-forward service/spring-mvc-traditional 8080:8080 --address=0.0.0.0
microk8s kubectl port-forward service/spring-virtual-threads 8081:8081 --address=0.0.0.0
microk8s kubectl port-forward service/spring-webflux 8082:8082 --address=0.0.0.0
```

Then access via VM IP:
```bash
curl http://vm-ip:8080/api/info
curl http://vm-ip:8081/api/info
curl http://vm-ip:8082/api/info
```

### Option 2: NodePort Services

Edit Kubernetes manifests to use NodePort:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: spring-mvc-traditional
spec:
  type: NodePort
  selector:
    app: spring-mvc-traditional
  ports:
  - protocol: TCP
    port: 8080
    targetPort: 8080
    nodePort: 30080  # External port
```

### Option 3: Ingress (Recommended)

If you enabled ingress addon:

```bash
# Deploy ingress
microk8s kubectl apply -f deployment/kubernetes/ingress.yaml

# Check ingress
microk8s kubectl get ingress

# Access via ingress (configure DNS or /etc/hosts)
curl http://spring-performance.local/mvc/api/info
curl http://spring-performance.local/virtual/api/info
curl http://spring-performance.local/webflux/api/info
```

## Scaling

```bash
# Scale deployments
microk8s kubectl scale deployment spring-mvc-traditional --replicas=3
microk8s kubectl scale deployment spring-virtual-threads --replicas=3
microk8s kubectl scale deployment spring-webflux --replicas=3

# Enable autoscaling
microk8s enable metrics-server
microk8s kubectl autoscale deployment spring-mvc-traditional --cpu-percent=70 --min=2 --max=10
```

## Monitoring

### Deploy Prometheus and Grafana

```bash
# Enable Helm addon
microk8s enable helm3

# Add Helm repositories
microk8s helm3 repo add prometheus-community https://prometheus-community.github.io/helm-charts
microk8s helm3 repo add grafana https://grafana.github.io/helm-charts
microk8s helm3 repo update

# Install Prometheus
microk8s helm3 install prometheus prometheus-community/prometheus

# Install Grafana
microk8s helm3 install grafana grafana/grafana

# Get Grafana password
microk8s kubectl get secret grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo

# Access Grafana
microk8s kubectl port-forward service/grafana 3000:80 --address=0.0.0.0
```

## Troubleshooting

### Check Pod Status

```bash
microk8s kubectl get pods
microk8s kubectl describe pod <pod-name>
microk8s kubectl logs <pod-name>
```

### Check Service Endpoints

```bash
microk8s kubectl get services
microk8s kubectl get endpoints
```

### Image Pull Issues

```bash
# Check images are imported
microk8s ctr images ls | grep spring-performance

# Re-import if needed
microk8s ctr image import /tmp/spring-mvc-traditional.tar
```

### Health Check Failed

```bash
# Check inside pod
microk8s kubectl exec -it <pod-name> -- curl http://localhost:8080/actuator/health

# Check pod logs
microk8s kubectl logs <pod-name> --tail=100
```

### microk8s Not Responding

```bash
# Check microk8s status
microk8s status

# Restart microk8s
microk8s stop
microk8s start

# Check system resources
free -h
df -h
```

## Advantages of microk8s Deployment

✅ **Kubernetes native** - Use standard Kubernetes tools and practices
✅ **Easy scaling** - Scale applications horizontally with one command
✅ **Load balancing** - Built-in service load balancing
✅ **Self-healing** - Automatic pod restart on failure
✅ **Resource management** - CPU and memory limits per pod
✅ **Rolling updates** - Zero-downtime deployments
✅ **Monitoring ready** - Easy integration with Prometheus/Grafana

## Performance Considerations

microk8s is lightweight but still adds overhead:
- **Pros**: Production-like environment, great for testing K8s deployments
- **Cons**: ~500MB RAM overhead for K8s components
- **Best for**: Development, staging, small production workloads
- **VM specs**: 4+ cores, 8+ GB RAM recommended for running all three apps

## Next Steps

1. Set up microk8s VM on Proxmox
2. Configure GitHub Secrets
3. Run the workflow manually or push to main/develop
4. Access your applications via port-forward or ingress
5. Set up monitoring with Prometheus/Grafana
