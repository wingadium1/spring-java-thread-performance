# Kubernetes Deployment Guide

## Prerequisites

1. Kubernetes cluster (1.19+)
2. kubectl configured to access the cluster
3. Docker images built and pushed to a registry

### microk8s (recommended for local / Proxmox VM deployments)

Enable the required addons before deploying:

```bash
# NGINX Ingress controller (ingressClass: public)
microk8s enable ingress

# MetalLB – assigns real LoadBalancer IPs to the ingress controller
# Replace the IP range with one that suits your network
microk8s enable metallb:192.168.1.200-192.168.1.220
```

After both addons are active, the NGINX ingress controller receives an external IP
from MetalLB.  All three Spring services are then reachable through that single IP
using path-based routing (no DNS or `/etc/hosts` entry required):

| Path prefix | Backend service | Example |
|---|---|---|
| `http://<LB-IP>/mvc/api/...` | spring-mvc-traditional | `http://<LB-IP>/mvc/api/hello` |
| `http://<LB-IP>/virtual/api/...` | spring-virtual-threads | `http://<LB-IP>/virtual/api/hello` |
| `http://<LB-IP>/webflux/api/...` | spring-webflux | `http://<LB-IP>/webflux/api/hello` |

## Building and Pushing Images

### Using Docker Registry

```bash
# Build images with Jib
mvn clean package jib:build -Djib.to.image=your-registry.com/spring-performance/spring-mvc-traditional:latest
mvn clean package jib:build -Djib.to.image=your-registry.com/spring-performance/spring-virtual-threads:latest
mvn clean package jib:build -Djib.to.image=your-registry.com/spring-performance/spring-webflux:latest
```

### Using Local Registry (for testing)

```bash
# Start a local registry
docker run -d -p 5000:5000 --name registry registry:2

# Build and push to local registry
mvn clean package jib:build -Djib.to.image=localhost:5000/spring-performance/spring-mvc-traditional:latest
mvn clean package jib:build -Djib.to.image=localhost:5000/spring-performance/spring-virtual-threads:latest
mvn clean package jib:build -Djib.to.image=localhost:5000/spring-performance/spring-webflux:latest
```

## Deploying to Kubernetes

### Deploy All Applications

```bash
kubectl apply -f deployment/kubernetes/spring-mvc-traditional.yaml
kubectl apply -f deployment/kubernetes/spring-virtual-threads.yaml
kubectl apply -f deployment/kubernetes/spring-webflux.yaml
```

### Deploy Ingress

The ingress manifest uses `ingressClassName: public` (microk8s built-in NGINX
addon) and strips path prefixes before forwarding requests to each service:

```bash
# microk8s (ingress + metallb addons must already be enabled)
microk8s kubectl apply -f deployment/kubernetes/ingress.yaml

# Standard kubectl
kubectl apply -f deployment/kubernetes/ingress.yaml
```

Get the external IP assigned by MetalLB:

```bash
microk8s kubectl get ingress spring-performance-ingress
# NAME                         CLASS    HOSTS   ADDRESS          PORTS   AGE
# spring-performance-ingress   public   *       192.168.1.200    80      1m
```

## Verification

### Check Deployments

```bash
kubectl get deployments
kubectl get pods
kubectl get services
kubectl get ingress
```

### Check Pod Status

```bash
kubectl get pods -l app=spring-mvc-traditional
kubectl get pods -l app=spring-virtual-threads
kubectl get pods -l app=spring-webflux
```

### View Logs

```bash
kubectl logs -l app=spring-mvc-traditional --tail=50 -f
kubectl logs -l app=spring-virtual-threads --tail=50 -f
kubectl logs -l app=spring-webflux --tail=50 -f
```

## Testing

### Using Ingress (via MetalLB IP)

Once the ingress has an external IP:

```bash
LB_IP=$(kubectl get ingress spring-performance-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

curl http://${LB_IP}/mvc/api/hello
curl http://${LB_IP}/virtual/api/hello
curl http://${LB_IP}/webflux/api/hello
```

### Port Forwarding (fallback without Ingress)

```bash
# Traditional MVC
kubectl port-forward service/spring-mvc-traditional 8080:8080

# Virtual Threads
kubectl port-forward service/spring-virtual-threads 8081:8081

# WebFlux
kubectl port-forward service/spring-webflux 8082:8082
```

Then test with:
```bash
curl http://localhost:8080/api/info
curl http://localhost:8081/api/info
curl http://localhost:8082/api/info
```

## Scaling

### Scale Deployments

```bash
# Scale Traditional MVC to 5 replicas
kubectl scale deployment spring-mvc-traditional --replicas=5

# Scale Virtual Threads to 5 replicas
kubectl scale deployment spring-virtual-threads --replicas=5

# Scale WebFlux to 5 replicas
kubectl scale deployment spring-webflux --replicas=5
```

### Auto-scaling (HPA)

```bash
# Enable horizontal pod autoscaling
kubectl autoscale deployment spring-mvc-traditional --cpu-percent=70 --min=2 --max=10
kubectl autoscale deployment spring-virtual-threads --cpu-percent=70 --min=2 --max=10
kubectl autoscale deployment spring-webflux --cpu-percent=70 --min=2 --max=10
```

## Resource Management

### View Resource Usage

```bash
kubectl top pods
kubectl top nodes
```

### Update Resource Limits

Edit the deployment YAML files and modify the `resources` section, then apply:
```bash
kubectl apply -f deployment/kubernetes/spring-mvc-traditional.yaml
```

## Cleanup

### Delete All Resources

```bash
kubectl delete -f deployment/kubernetes/spring-mvc-traditional.yaml
kubectl delete -f deployment/kubernetes/spring-virtual-threads.yaml
kubectl delete -f deployment/kubernetes/spring-webflux.yaml
kubectl delete -f deployment/kubernetes/ingress.yaml
```

## Monitoring

### Install Prometheus and Grafana (using Helm)

```bash
# Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus
helm install prometheus prometheus-community/prometheus

# Install Grafana
helm install grafana grafana/grafana

# Get Grafana admin password
kubectl get secret --namespace default grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

### Access Prometheus and Grafana

```bash
# Prometheus
kubectl port-forward service/prometheus-server 9090:80

# Grafana
kubectl port-forward service/grafana 3000:80
```

## Troubleshooting

### Check Pod Events

```bash
kubectl describe pod <pod-name>
```

### View Container Logs

```bash
kubectl logs <pod-name>
```

### Execute Commands in Pod

```bash
kubectl exec -it <pod-name> -- /bin/sh
```

### Check Service Endpoints

```bash
kubectl get endpoints
```
