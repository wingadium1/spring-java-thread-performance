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
sleep 5

# Test Virtual Threads
echo "========================================="
echo "Testing Spring Virtual Threads (/virtual)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s ${BASE_URL}/virtual/api/query | tee $RESULTS_DIR/virtual-threads.txt
echo ""
sleep 5

# Test WebFlux
echo "========================================="
echo "Testing Spring WebFlux (/webflux)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s ${BASE_URL}/webflux/api/query | tee $RESULTS_DIR/webflux.txt
echo ""

# Test with high delay
echo "========================================="
echo "Testing with 500ms delay (Traditional MVC)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s ${BASE_URL}/mvc/api/query/500 | tee $RESULTS_DIR/mvc-traditional-500ms.txt
echo ""
sleep 5

echo "========================================="
echo "Testing with 500ms delay (Virtual Threads)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s ${BASE_URL}/virtual/api/query/500 | tee $RESULTS_DIR/virtual-threads-500ms.txt
echo ""
sleep 5

echo "========================================="
echo "Testing with 500ms delay (WebFlux)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s ${BASE_URL}/webflux/api/query/500 | tee $RESULTS_DIR/webflux-500ms.txt
echo ""

# Test CPU endpoint
echo "========================================="
echo "Testing CPU endpoint (Traditional MVC)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s ${BASE_URL}/mvc/api/cpu/${CPU_DURATION_MS} | tee $RESULTS_DIR/mvc-cpu.txt
echo ""
sleep 5

echo "========================================="
echo "Testing CPU endpoint (Virtual Threads)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s ${BASE_URL}/virtual/api/cpu/${CPU_DURATION_MS} | tee $RESULTS_DIR/virtual-cpu.txt
echo ""
sleep 5

echo "========================================="
echo "Testing CPU endpoint (WebFlux)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s ${BASE_URL}/webflux/api/cpu/${CPU_DURATION_MS} | tee $RESULTS_DIR/webflux-cpu.txt
echo ""
sleep 5

# Test stress endpoint
echo "========================================="
echo "Testing stress endpoint (Traditional MVC)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s "${BASE_URL}/mvc/api/stress?queries=${STRESS_QUERIES}&cpuMs=${STRESS_CPU_MS}" | tee $RESULTS_DIR/mvc-stress.txt
echo ""
sleep 5

echo "========================================="
echo "Testing stress endpoint (Virtual Threads)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s "${BASE_URL}/virtual/api/stress?queries=${STRESS_QUERIES}&cpuMs=${STRESS_CPU_MS}" | tee $RESULTS_DIR/virtual-stress.txt
echo ""
sleep 5

echo "========================================="
echo "Testing stress endpoint (WebFlux)"
echo "========================================="
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s "${BASE_URL}/webflux/api/stress?queries=${STRESS_QUERIES}&cpuMs=${STRESS_CPU_MS}" | tee $RESULTS_DIR/webflux-stress.txt
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
