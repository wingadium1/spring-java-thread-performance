#!/bin/bash

# Advanced load testing script using wrk
# Usage: ./load-test-wrk.sh [threads] [connections] [duration]

THREADS=${1:-4}
CONNECTIONS=${2:-100}
DURATION=${3:-30}

echo "Load Testing Configuration:"
echo "  Threads: $THREADS"
echo "  Connections: $CONNECTIONS"
echo "  Duration: ${DURATION}s"
echo ""

# Check if wrk is installed
if ! command -v wrk &> /dev/null; then
    echo "wrk is not installed."
    echo "Install with: sudo apt-get install wrk (Ubuntu/Debian)"
    echo "          or: brew install wrk (macOS)"
    exit 1
fi

# Create results directory
RESULTS_DIR="load-test-results-$(date +%Y%m%d-%H%M%S)"
mkdir -p $RESULTS_DIR

echo "Results will be saved to: $RESULTS_DIR"
echo ""

# Test Traditional MVC
echo "========================================="
echo "Testing Traditional Spring MVC (port 8080)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s http://localhost:8080/api/query | tee $RESULTS_DIR/mvc-traditional.txt
echo ""
sleep 5

# Test Virtual Threads
echo "========================================="
echo "Testing Spring Virtual Threads (port 8081)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s http://localhost:8081/api/query | tee $RESULTS_DIR/virtual-threads.txt
echo ""
sleep 5

# Test WebFlux
echo "========================================="
echo "Testing Spring WebFlux (port 8082)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s http://localhost:8082/api/query | tee $RESULTS_DIR/webflux.txt
echo ""

# Test with high delay
echo "========================================="
echo "Testing with 500ms delay (Traditional MVC)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s http://localhost:8080/api/query/500 | tee $RESULTS_DIR/mvc-traditional-500ms.txt
echo ""
sleep 5

echo "========================================="
echo "Testing with 500ms delay (Virtual Threads)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s http://localhost:8081/api/query/500 | tee $RESULTS_DIR/virtual-threads-500ms.txt
echo ""
sleep 5

echo "========================================="
echo "Testing with 500ms delay (WebFlux)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s http://localhost:8082/api/query/500 | tee $RESULTS_DIR/webflux-500ms.txt
echo ""

echo "Load testing complete!"
echo "Results saved to: $RESULTS_DIR"
echo ""
echo "Summary:"
echo "--------"
echo "Traditional MVC:"
grep "Requests/sec:" $RESULTS_DIR/mvc-traditional.txt
echo ""
echo "Virtual Threads:"
grep "Requests/sec:" $RESULTS_DIR/virtual-threads.txt
echo ""
echo "WebFlux:"
grep "Requests/sec:" $RESULTS_DIR/webflux.txt
