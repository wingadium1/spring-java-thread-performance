#!/bin/bash

# Advanced load testing script using wrk
# Usage: ./load-test-wrk.sh [threads] [connections] [duration] [base_url] [cpu_duration_ms] [stress_queries] [stress_cpu_ms]
#
# base_url is the ingress endpoint (e.g. http://192.168.1.200).
# Traffic is routed by the NGINX ingress using path prefixes:
#   /mvc/api/...     -> spring-mvc-traditional
#   /virtual/api/... -> spring-virtual-threads
#   /webflux/api/... -> spring-webflux
#
# Tested endpoints:
#   GET /api/query             - Simple database query
#   GET /api/query/{delay}     - Database query with artificial delay (ms)
#   GET /api/cpu/{durationMs}  - CPU-intensive work for specified duration
#   GET /api/stress?queries=N&cpuMs=M  - Combined stress test (I/O + CPU + memory)

THREADS=${1:-4}
CONNECTIONS=${2:-100}
DURATION=${3:-30}
BASE_URL=${4:-http://localhost}
CPU_DURATION_MS=${5:-100}
STRESS_QUERIES=${6:-5}
STRESS_CPU_MS=${7:-100}

echo "Load Testing Configuration:"
echo "  Threads: $THREADS"
echo "  Connections: $CONNECTIONS"
echo "  Duration: ${DURATION}s"
echo "  Base URL: $BASE_URL"
echo "  CPU Duration: ${CPU_DURATION_MS}ms"
echo "  Stress Queries: $STRESS_QUERIES"
echo "  Stress CPU: ${STRESS_CPU_MS}ms"
echo ""

# Check if wrk is installed
if ! command -v wrk &> /dev/null; then
    echo "wrk is not installed."
    echo "Install with: sudo apt-get install wrk (Ubuntu/Debian)"
    echo "          or: brew install wrk (macOS)"
    exit 1
fi

# Function to wait for all requests to complete
# This checks the Prometheus metrics endpoint to ensure no active requests
wait_for_requests_to_complete() {
    local service_path=$1
    local max_wait=120  # Maximum wait time in seconds
    local check_interval=2
    local elapsed=0
    
    echo "Waiting for all requests to complete on ${service_path}..."
    
    while [ $elapsed -lt $max_wait ]; do
        # Try to get the active request count from metrics
        # http_server_requests_active_count is a common metric
        local active_requests=$(curl -s "${BASE_URL}${service_path}/actuator/prometheus" 2>/dev/null | \
            grep -E 'http_server_requests_active|tomcat_threads_busy_threads|reactor_netty_http_server_connections_active' | \
            grep -v '#' | \
            awk '{sum+=$NF} END {print sum+0}')
        
        if [ "$active_requests" = "0" ] || [ -z "$active_requests" ]; then
            echo "✓ All requests completed (active requests: ${active_requests:-0})"
            # Additional small sleep to ensure metric reporting has settled
            sleep 5
            return 0
        fi
        
        echo "  Still processing... (active requests: ${active_requests}, waited ${elapsed}s)"
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done
    
    echo "⚠ Timeout waiting for requests to complete after ${max_wait}s"
    # Continue anyway after timeout
    return 0
}

# Create results directory
RESULTS_DIR="load-test-results-$(date +%Y%m%d-%H%M%S)"
mkdir -p $RESULTS_DIR

echo "Results will be saved to: $RESULTS_DIR"
echo ""

# Test Traditional MVC
echo "========================================="
echo "Testing Traditional Spring MVC (/mvc)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s ${BASE_URL}/mvc/api/query | tee $RESULTS_DIR/mvc-traditional.txt
echo ""
wait_for_requests_to_complete "/mvc"
sleep 60

# Test Virtual Threads
echo "========================================="
echo "Testing Spring Virtual Threads (/virtual)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s ${BASE_URL}/virtual/api/query | tee $RESULTS_DIR/virtual-threads.txt
echo ""
wait_for_requests_to_complete "/virtual"
sleep 60

# Test WebFlux
echo "========================================="
echo "Testing Spring WebFlux (/webflux)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s ${BASE_URL}/webflux/api/query | tee $RESULTS_DIR/webflux.txt
echo ""
wait_for_requests_to_complete "/webflux"
sleep 60

# Test with high delay
echo "========================================="
echo "Testing with 500ms delay (Traditional MVC)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s ${BASE_URL}/mvc/api/query/500 | tee $RESULTS_DIR/mvc-traditional-500ms.txt
echo ""
wait_for_requests_to_complete "/mvc"
sleep 60

echo "========================================="
echo "Testing with 500ms delay (Virtual Threads)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s ${BASE_URL}/virtual/api/query/500 | tee $RESULTS_DIR/virtual-threads-500ms.txt
echo ""
wait_for_requests_to_complete "/virtual"
sleep 60

echo "========================================="
echo "Testing with 500ms delay (WebFlux)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s ${BASE_URL}/webflux/api/query/500 | tee $RESULTS_DIR/webflux-500ms.txt
echo ""
wait_for_requests_to_complete "/webflux"
sleep 60

# Test CPU endpoint
echo "========================================="
echo "Testing CPU endpoint (Traditional MVC)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s ${BASE_URL}/mvc/api/cpu/${CPU_DURATION_MS} | tee $RESULTS_DIR/mvc-cpu.txt
echo ""
wait_for_requests_to_complete "/mvc"
sleep 60

echo "========================================="
echo "Testing CPU endpoint (Virtual Threads)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s ${BASE_URL}/virtual/api/cpu/${CPU_DURATION_MS} | tee $RESULTS_DIR/virtual-cpu.txt
echo ""
wait_for_requests_to_complete "/virtual"
sleep 60

echo "========================================="
echo "Testing CPU endpoint (WebFlux)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s ${BASE_URL}/webflux/api/cpu/${CPU_DURATION_MS} | tee $RESULTS_DIR/webflux-cpu.txt
echo ""
wait_for_requests_to_complete "/webflux"
sleep 60

# Test stress endpoint
echo "========================================="
echo "Testing stress endpoint (Traditional MVC)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s "${BASE_URL}/mvc/api/stress?queries=${STRESS_QUERIES}&cpuMs=${STRESS_CPU_MS}" | tee $RESULTS_DIR/mvc-stress.txt
echo ""
wait_for_requests_to_complete "/mvc"
sleep 60

echo "========================================="
echo "Testing stress endpoint (Virtual Threads)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s "${BASE_URL}/virtual/api/stress?queries=${STRESS_QUERIES}&cpuMs=${STRESS_CPU_MS}" | tee $RESULTS_DIR/virtual-stress.txt
echo ""
wait_for_requests_to_complete "/virtual"
sleep 60

echo "========================================="
echo "Testing stress endpoint (WebFlux)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s "${BASE_URL}/webflux/api/stress?queries=${STRESS_QUERIES}&cpuMs=${STRESS_CPU_MS}" | tee $RESULTS_DIR/webflux-stress.txt
echo ""
wait_for_requests_to_complete "/webflux"

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
echo ""
echo "CPU Test (Traditional MVC):"
grep "Requests/sec:" $RESULTS_DIR/mvc-cpu.txt
echo ""
echo "CPU Test (Virtual Threads):"
grep "Requests/sec:" $RESULTS_DIR/virtual-cpu.txt
echo ""
echo "CPU Test (WebFlux):"
grep "Requests/sec:" $RESULTS_DIR/webflux-cpu.txt
echo ""
echo "Stress Test (Traditional MVC):"
grep "Requests/sec:" $RESULTS_DIR/mvc-stress.txt
echo ""
echo "Stress Test (Virtual Threads):"
grep "Requests/sec:" $RESULTS_DIR/virtual-stress.txt
echo ""
echo "Stress Test (WebFlux):"
grep "Requests/sec:" $RESULTS_DIR/webflux-stress.txt
