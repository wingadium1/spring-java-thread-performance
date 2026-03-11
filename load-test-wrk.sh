#!/bin/bash

set -euo pipefail

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
#   GET /api/query                    - Simple database query
#   GET /api/query/{delay}            - Database query with artificial delay (ms)
#   GET /api/cpu/{durationMs}         - CPU-intensive work for specified duration
#   GET /api/stress?queries=N&cpuMs=M - Combined stress test (I/O + CPU + memory)
#   GET /api/wait/{delayMs}           - Wait endpoint (blocking in MVC/Virtual, non-blocking in WebFlux)
#   GET /api/sse/{events}?intervalMs= - SSE/streaming endpoint comparison

THREADS=${1:-4}
CONNECTIONS=${2:-100}
DURATION=${3:-30}
BASE_URL=${4:-http://localhost}
CPU_DURATION_MS=${5:-100}
STRESS_QUERIES=${6:-5}
STRESS_CPU_MS=${7:-100}
WAIT_DELAY_MS=${WAIT_DELAY_MS:-1000}
SSE_EVENTS=${SSE_EVENTS:-10}
SSE_INTERVAL_MS=${SSE_INTERVAL_MS:-100}
SETTLE_SECONDS=${SETTLE_SECONDS:-15}

echo "Load Testing Configuration:"
echo "  Threads: $THREADS"
echo "  Connections: $CONNECTIONS"
echo "  Duration: ${DURATION}s"
echo "  Base URL: $BASE_URL"
echo "  CPU Duration: ${CPU_DURATION_MS}ms"
echo "  Stress Queries: $STRESS_QUERIES"
echo "  Stress CPU: ${STRESS_CPU_MS}ms"
echo "  Wait Delay: ${WAIT_DELAY_MS}ms"
echo "  SSE Events: ${SSE_EVENTS}"
echo "  SSE Interval: ${SSE_INTERVAL_MS}ms"
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
mkdir -p "$RESULTS_DIR"

echo "Results will be saved to: $RESULTS_DIR"
echo ""

run_case() {
    local label="$1"
    local path="$2"
    local output_file="$RESULTS_DIR/$3"
    local service_prefix="$4"

    echo "========================================="
    echo "$label"
    echo "========================================="
    wrk --latency -t"$THREADS" -c"$CONNECTIONS" -d"${DURATION}s" "$BASE_URL/$path" | tee "$output_file"
    echo ""

    wait_for_requests_to_complete "$service_prefix"
    sleep "$SETTLE_SECONDS"
}

echo "Scenario set:"
echo "  1. Standard query"
echo "  2. Delayed query (500ms)"
echo "  3. CPU-intensive endpoint (${CPU_DURATION_MS}ms)"
echo "  4. Mixed stress workload (queries=${STRESS_QUERIES}, cpuMs=${STRESS_CPU_MS})"
echo "  5. Wait endpoint showcase (${WAIT_DELAY_MS}ms)"
echo "  6. SSE streaming (${SSE_EVENTS} events, ${SSE_INTERVAL_MS}ms interval)"
echo ""
run_case "Testing Traditional Spring MVC query (/mvc/api/query)" \
    "mvc/api/query" "mvc-traditional.txt" "/mvc"
run_case "Testing Spring Virtual Threads query (/virtual/api/query)" \
    "virtual/api/query" "virtual-threads.txt" "/virtual"
run_case "Testing Spring WebFlux query (/webflux/api/query)" \
    "webflux/api/query" "webflux.txt" "/webflux"

run_case "Testing Traditional MVC 500ms query (/mvc/api/query/500)" \
    "mvc/api/query/500" "mvc-traditional-500ms.txt" "/mvc"
run_case "Testing Virtual Threads 500ms query (/virtual/api/query/500)" \
    "virtual/api/query/500" "virtual-threads-500ms.txt" "/virtual"
run_case "Testing WebFlux 500ms query (/webflux/api/query/500)" \
    "webflux/api/query/500" "webflux-500ms.txt" "/webflux"

run_case "Testing Traditional MVC CPU (${CPU_DURATION_MS}ms)" \
    "mvc/api/cpu/${CPU_DURATION_MS}" "mvc-cpu.txt" "/mvc"
run_case "Testing Virtual Threads CPU (${CPU_DURATION_MS}ms)" \
    "virtual/api/cpu/${CPU_DURATION_MS}" "virtual-cpu.txt" "/virtual"
run_case "Testing WebFlux CPU (${CPU_DURATION_MS}ms)" \
    "webflux/api/cpu/${CPU_DURATION_MS}" "webflux-cpu.txt" "/webflux"

run_case "Testing Traditional MVC stress" \
    "mvc/api/stress?queries=${STRESS_QUERIES}&cpuMs=${STRESS_CPU_MS}" "mvc-stress.txt" "/mvc"
run_case "Testing Virtual Threads stress" \
    "virtual/api/stress?queries=${STRESS_QUERIES}&cpuMs=${STRESS_CPU_MS}" "virtual-stress.txt" "/virtual"
run_case "Testing WebFlux stress" \
    "webflux/api/stress?queries=${STRESS_QUERIES}&cpuMs=${STRESS_CPU_MS}" "webflux-stress.txt" "/webflux"

run_case "Testing Traditional MVC blocking wait (${WAIT_DELAY_MS}ms)" \
    "mvc/api/wait/${WAIT_DELAY_MS}" "mvc-wait.txt" "/mvc"
run_case "Testing Virtual Threads blocking wait (${WAIT_DELAY_MS}ms)" \
    "virtual/api/wait/${WAIT_DELAY_MS}" "virtual-wait.txt" "/virtual"
run_case "Testing WebFlux non-blocking wait (${WAIT_DELAY_MS}ms)" \
    "webflux/api/wait/${WAIT_DELAY_MS}" "webflux-wait.txt" "/webflux"

run_case "Testing Traditional MVC SSE (${SSE_EVENTS} events)" \
    "mvc/api/sse/${SSE_EVENTS}?intervalMs=${SSE_INTERVAL_MS}" "mvc-sse.txt" "/mvc"
run_case "Testing Virtual Threads SSE (${SSE_EVENTS} events)" \
    "virtual/api/sse/${SSE_EVENTS}?intervalMs=${SSE_INTERVAL_MS}" "virtual-sse.txt" "/virtual"
run_case "Testing WebFlux SSE (${SSE_EVENTS} events)" \
    "webflux/api/sse/${SSE_EVENTS}?intervalMs=${SSE_INTERVAL_MS}" "webflux-sse.txt" "/webflux"

echo "Load testing complete!"
echo "Results saved to: $RESULTS_DIR"
echo ""
echo "Summary:"
echo "--------"
if [[ -x "./summarize-wrk-results.sh" ]]; then
    ./summarize-wrk-results.sh "$RESULTS_DIR" markdown
else
    echo "Traditional MVC query:"
    grep "Requests/sec:" "$RESULTS_DIR/mvc-traditional.txt" || true
    echo ""
    echo "Virtual Threads query:"
    grep "Requests/sec:" "$RESULTS_DIR/virtual-threads.txt" || true
    echo ""
    echo "WebFlux query:"
    grep "Requests/sec:" "$RESULTS_DIR/webflux.txt" || true
fi
