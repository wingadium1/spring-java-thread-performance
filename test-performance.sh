#!/bin/bash

# Performance testing script using Apache Bench
# Usage: ./test-performance.sh [requests] [concurrency]

REQUESTS=${1:-1000}
CONCURRENCY=${2:-50}

echo "Performance Testing Configuration:"
echo "  Requests: $REQUESTS"
echo "  Concurrency: $CONCURRENCY"
echo ""

# Check if ab is installed
if ! command -v ab &> /dev/null; then
    echo "Apache Bench (ab) is not installed."
    echo "Install with: sudo apt-get install apache2-utils (Ubuntu/Debian)"
    echo "          or: brew install httpd (macOS)"
    exit 1
fi

# Test Traditional MVC
echo "========================================="
echo "Testing Traditional Spring MVC (port 8080)"
echo "========================================="
ab -n $REQUESTS -c $CONCURRENCY http://localhost:8080/api/query
echo ""

# Test Virtual Threads
echo "========================================="
echo "Testing Spring Virtual Threads (port 8081)"
echo "========================================="
ab -n $REQUESTS -c $CONCURRENCY http://localhost:8081/api/query
echo ""

# Test WebFlux
echo "========================================="
echo "Testing Spring WebFlux (port 8082)"
echo "========================================="
ab -n $REQUESTS -c $CONCURRENCY http://localhost:8082/api/query
echo ""

echo "Performance testing complete!"
