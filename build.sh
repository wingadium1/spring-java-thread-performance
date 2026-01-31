#!/bin/bash

# Build script for all modules
echo "Building Spring Boot Performance Comparison Project..."

# Build all modules
echo "Building all modules with Maven..."
mvn clean package

if [ $? -eq 0 ]; then
    echo "✓ Maven build successful"
else
    echo "✗ Maven build failed"
    exit 1
fi

# Build Docker images with Jib
echo "Building Docker images with Jib..."
mvn jib:dockerBuild

if [ $? -eq 0 ]; then
    echo "✓ Docker images built successfully"
    echo ""
    echo "Available images:"
    docker images | grep spring-performance
else
    echo "✗ Docker build failed"
    exit 1
fi

echo ""
echo "Build complete! You can now run:"
echo "  docker-compose up -d"
