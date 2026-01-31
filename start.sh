#!/bin/bash

# Quick start script for all applications
echo "Starting all Spring Boot applications..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Docker is not running. Please start Docker first."
    exit 1
fi

# Check if images exist
if ! docker images | grep -q "spring-performance/spring-mvc-traditional"; then
    echo "Docker images not found. Building images..."
    ./build.sh
fi

# Start all services
echo "Starting services with Docker Compose..."
docker-compose up -d

# Wait for services to be healthy
echo "Waiting for services to be ready..."
sleep 10

# Check health of each service
echo ""
echo "Checking service health..."

echo -n "Traditional MVC (8080): "
curl -s http://localhost:8080/actuator/health | grep -q "UP" && echo "✓ UP" || echo "✗ DOWN"

echo -n "Virtual Threads (8081): "
curl -s http://localhost:8081/actuator/health | grep -q "UP" && echo "✓ UP" || echo "✗ DOWN"

echo -n "WebFlux (8082): "
curl -s http://localhost:8082/actuator/health | grep -q "UP" && echo "✓ UP" || echo "✗ DOWN"

echo ""
echo "Services are starting! Access points:"
echo "  Traditional MVC:  http://localhost:8080/api/info"
echo "  Virtual Threads:  http://localhost:8081/api/info"
echo "  WebFlux:          http://localhost:8082/api/info"
echo "  Prometheus:       http://localhost:9090"
echo "  Grafana:          http://localhost:3000 (admin/admin)"
echo ""
echo "View logs with: docker-compose logs -f"
echo "Stop services with: docker-compose down"
