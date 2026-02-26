#!/bin/bash

# Test Proxmox Deployment Script
# This script helps you test the deployment to Proxmox before running it through GitHub Actions

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if required environment variables are set
check_requirements() {
    print_info "Checking requirements..."
    
    if [ -z "$PROXMOX_HOST" ]; then
        print_error "PROXMOX_HOST environment variable is not set"
        exit 1
    fi
    
    if [ -z "$PROXMOX_USER" ]; then
        print_error "PROXMOX_USER environment variable is not set"
        exit 1
    fi
    
    if [ -z "$PROXMOX_SSH_KEY_PATH" ]; then
        print_error "PROXMOX_SSH_KEY_PATH environment variable is not set"
        exit 1
    fi
    
    if [ ! -f "$PROXMOX_SSH_KEY_PATH" ]; then
        print_error "SSH key file not found at: $PROXMOX_SSH_KEY_PATH"
        exit 1
    fi
    
    # Set default deployment method if not specified
    PROXMOX_DEPLOY_METHOD=${PROXMOX_DEPLOY_METHOD:-systemd}
    
    print_info "Configuration:"
    echo "  Host: $PROXMOX_HOST"
    echo "  User: $PROXMOX_USER"
    echo "  SSH Key: $PROXMOX_SSH_KEY_PATH"
    echo "  Deploy Method: $PROXMOX_DEPLOY_METHOD"
}

# Test SSH connection
test_ssh_connection() {
    print_info "Testing SSH connection to Proxmox server..."
    
    if ssh -i "$PROXMOX_SSH_KEY_PATH" -o ConnectTimeout=10 "$PROXMOX_USER@$PROXMOX_HOST" "echo 'SSH connection successful'"; then
        print_info "SSH connection successful"
    else
        print_error "SSH connection failed. Please check your credentials."
        exit 1
    fi
}

# Build the project
build_project() {
    print_info "Building the project..."
    
    if mvn clean package; then
        print_info "Build successful"
    else
        print_error "Build failed"
        exit 1
    fi
}

# Build Docker images
build_docker_images() {
    print_info "Building Docker images with Jib..."
    
    if mvn jib:dockerBuild; then
        print_info "Docker images built successfully"
        docker images | grep spring-performance
    else
        print_error "Docker image build failed"
        exit 1
    fi
}

# Deploy JAR files
deploy_jars() {
    print_info "Deploying JAR files to Proxmox..."
    
    # Create deployment directory
    ssh -i "$PROXMOX_SSH_KEY_PATH" "$PROXMOX_USER@$PROXMOX_HOST" \
        "sudo mkdir -p /opt/spring-performance && sudo chown $PROXMOX_USER:$PROXMOX_USER /opt/spring-performance"
    
    # Copy JAR files
    print_info "Copying spring-mvc-traditional JAR..."
    scp -i "$PROXMOX_SSH_KEY_PATH" spring-mvc-traditional/target/*.jar \
        "$PROXMOX_USER@$PROXMOX_HOST:/opt/spring-performance/"
    
    print_info "Copying spring-virtual-threads JAR..."
    scp -i "$PROXMOX_SSH_KEY_PATH" spring-virtual-threads/target/*.jar \
        "$PROXMOX_USER@$PROXMOX_HOST:/opt/spring-performance/"
    
    print_info "Copying spring-webflux JAR..."
    scp -i "$PROXMOX_SSH_KEY_PATH" spring-webflux/target/*.jar \
        "$PROXMOX_USER@$PROXMOX_HOST:/opt/spring-performance/"
    
    print_info "JAR files deployed successfully"
}

# Deploy with systemd
deploy_systemd() {
    print_info "Deploying systemd services..."
    
    # Copy systemd service files
    scp -i "$PROXMOX_SSH_KEY_PATH" deployment/*.service \
        "$PROXMOX_USER@$PROXMOX_HOST:/tmp/"
    
    # Install and restart services
    ssh -i "$PROXMOX_SSH_KEY_PATH" "$PROXMOX_USER@$PROXMOX_HOST" << 'ENDSSH'
        sudo cp /tmp/*.service /etc/systemd/system/
        sudo systemctl daemon-reload
        sudo systemctl restart spring-mvc-traditional || true
        sudo systemctl restart spring-virtual-threads || true
        sudo systemctl restart spring-webflux || true
        sudo systemctl enable spring-mvc-traditional
        sudo systemctl enable spring-virtual-threads
        sudo systemctl enable spring-webflux
ENDSSH
    
    print_info "Systemd services deployed and started"
}

# Deploy with Docker
deploy_docker() {
    print_info "Deploying Docker images to Proxmox..."
    
    # Save Docker images
    mkdir -p /tmp/docker-images
    docker save spring-performance/spring-mvc-traditional:latest -o /tmp/docker-images/spring-mvc-traditional.tar
    docker save spring-performance/spring-virtual-threads:latest -o /tmp/docker-images/spring-virtual-threads.tar
    docker save spring-performance/spring-webflux:latest -o /tmp/docker-images/spring-webflux.tar
    
    # Transfer Docker images
    print_info "Transferring Docker images..."
    scp -i "$PROXMOX_SSH_KEY_PATH" /tmp/docker-images/*.tar \
        "$PROXMOX_USER@$PROXMOX_HOST:/tmp/"
    
    # Load and run Docker images
    ssh -i "$PROXMOX_SSH_KEY_PATH" "$PROXMOX_USER@$PROXMOX_HOST" << 'ENDSSH'
        echo "Loading Docker images..."
        docker load < /tmp/spring-mvc-traditional.tar
        docker load < /tmp/spring-virtual-threads.tar
        docker load < /tmp/spring-webflux.tar
        
        echo "Stopping existing containers..."
        docker stop spring-mvc-traditional spring-virtual-threads spring-webflux 2>/dev/null || true
        docker rm spring-mvc-traditional spring-virtual-threads spring-webflux 2>/dev/null || true
        
        echo "Starting new containers..."
        docker run -d --name spring-mvc-traditional -p 8080:8080 \
            -e JAVA_TOOL_OPTIONS="-Xms512m -Xmx2g" \
            spring-performance/spring-mvc-traditional:latest
        
        docker run -d --name spring-virtual-threads -p 8081:8081 \
            -e JAVA_TOOL_OPTIONS="-Xms512m -Xmx2g" \
            spring-performance/spring-virtual-threads:latest
        
        docker run -d --name spring-webflux -p 8082:8082 \
            -e JAVA_TOOL_OPTIONS="-Xms512m -Xmx2g" \
            spring-performance/spring-webflux:latest
        
        rm /tmp/*.tar
ENDSSH
    
    # Cleanup local images
    rm -rf /tmp/docker-images
    
    print_info "Docker containers deployed and started"
}

# Deploy with Docker Compose
deploy_docker_compose() {
    print_info "Deploying with Docker Compose..."
    
    # Save Docker images
    mkdir -p /tmp/docker-images
    docker save spring-performance/spring-mvc-traditional:latest -o /tmp/docker-images/spring-mvc-traditional.tar
    docker save spring-performance/spring-virtual-threads:latest -o /tmp/docker-images/spring-virtual-threads.tar
    docker save spring-performance/spring-webflux:latest -o /tmp/docker-images/spring-webflux.tar
    
    # Transfer Docker images
    print_info "Transferring Docker images..."
    scp -i "$PROXMOX_SSH_KEY_PATH" /tmp/docker-images/*.tar \
        "$PROXMOX_USER@$PROXMOX_HOST:/tmp/"
    
    # Transfer docker-compose.yml
    print_info "Transferring docker-compose.yml..."
    scp -i "$PROXMOX_SSH_KEY_PATH" docker-compose.yml \
        "$PROXMOX_USER@$PROXMOX_HOST:/opt/spring-performance/"
    
    # Transfer monitoring configs
    print_info "Transferring monitoring configs..."
    ssh -i "$PROXMOX_SSH_KEY_PATH" "$PROXMOX_USER@$PROXMOX_HOST" \
        "mkdir -p /opt/spring-performance/monitoring"
    scp -i "$PROXMOX_SSH_KEY_PATH" monitoring/*.yml \
        "$PROXMOX_USER@$PROXMOX_HOST:/opt/spring-performance/monitoring/"
    
    # Load images and start services
    ssh -i "$PROXMOX_SSH_KEY_PATH" "$PROXMOX_USER@$PROXMOX_HOST" << 'ENDSSH'
        echo "Loading Docker images..."
        docker load < /tmp/spring-mvc-traditional.tar
        docker load < /tmp/spring-virtual-threads.tar
        docker load < /tmp/spring-webflux.tar
        rm /tmp/*.tar
        
        echo "Starting services with Docker Compose..."
        cd /opt/spring-performance
        docker-compose down
        docker-compose up -d
ENDSSH
    
    # Cleanup local images
    rm -rf /tmp/docker-images
    
    print_info "Docker Compose deployment complete"
}

# Health check
health_check() {
    print_info "Waiting 30 seconds for services to start..."
    sleep 30
    
    print_info "Running health checks..."
    
    ssh -i "$PROXMOX_SSH_KEY_PATH" "$PROXMOX_USER@$PROXMOX_HOST" << 'ENDSSH'
        echo "Checking Spring MVC Traditional (port 8080)..."
        if curl -f -s http://localhost:8080/actuator/health > /dev/null; then
            echo "✓ Spring MVC Traditional is healthy"
        else
            echo "✗ Spring MVC Traditional not responding"
        fi
        
        echo "Checking Spring Virtual Threads (port 8081)..."
        if curl -f -s http://localhost:8081/actuator/health > /dev/null; then
            echo "✓ Spring Virtual Threads is healthy"
        else
            echo "✗ Spring Virtual Threads not responding"
        fi
        
        echo "Checking Spring WebFlux (port 8082)..."
        if curl -f -s http://localhost:8082/actuator/health > /dev/null; then
            echo "✓ Spring WebFlux is healthy"
        else
            echo "✗ Spring WebFlux not responding"
        fi
ENDSSH
}

# Main execution
main() {
    echo "================================================"
    echo "  Proxmox Deployment Test Script"
    echo "================================================"
    echo ""
    
    check_requirements
    echo ""
    
    test_ssh_connection
    echo ""
    
    build_project
    echo ""
    
    if [ "$PROXMOX_DEPLOY_METHOD" = "docker" ] || [ "$PROXMOX_DEPLOY_METHOD" = "docker-compose" ]; then
        build_docker_images
        echo ""
    fi
    
    deploy_jars
    echo ""
    
    case "$PROXMOX_DEPLOY_METHOD" in
        systemd)
            deploy_systemd
            ;;
        docker)
            deploy_docker
            ;;
        docker-compose)
            deploy_docker_compose
            ;;
        *)
            print_warning "Unknown deploy method: $PROXMOX_DEPLOY_METHOD, using systemd"
            deploy_systemd
            ;;
    esac
    echo ""
    
    health_check
    echo ""
    
    print_info "Deployment test complete!"
    echo ""
    echo "You can now access your applications at:"
    echo "  - Spring MVC Traditional: http://$PROXMOX_HOST:8080"
    echo "  - Spring Virtual Threads: http://$PROXMOX_HOST:8081"
    echo "  - Spring WebFlux: http://$PROXMOX_HOST:8082"
}

# Usage information
usage() {
    echo "Usage: $0"
    echo ""
    echo "Required environment variables:"
    echo "  PROXMOX_HOST            - Proxmox server IP or hostname"
    echo "  PROXMOX_USER            - SSH username"
    echo "  PROXMOX_SSH_KEY_PATH    - Path to SSH private key"
    echo ""
    echo "Optional environment variables:"
    echo "  PROXMOX_DEPLOY_METHOD   - Deployment method (systemd|docker|docker-compose)"
    echo "                            Default: systemd"
    echo ""
    echo "Example:"
    echo "  export PROXMOX_HOST=192.168.1.100"
    echo "  export PROXMOX_USER=ubuntu"
    echo "  export PROXMOX_SSH_KEY_PATH=~/.ssh/proxmox_deploy"
    echo "  export PROXMOX_DEPLOY_METHOD=systemd"
    echo "  $0"
}

# Check if help is requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
    exit 0
fi

# Run main function
main
