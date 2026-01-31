#!/bin/bash

# Demonstration script showing different workload profiles
# Run this to see how different profiles affect performance

echo "========================================="
echo "Workload Profile Demonstration"
echo "========================================="
echo ""

PORT=${1:-8080}
ENDPOINT="http://localhost:$PORT"

echo "Testing endpoint: $ENDPOINT"
echo ""

# Test different profiles by making API calls
echo "1. Testing with current profile (check /api/info):"
PROFILE_INFO=$(curl -s "$ENDPOINT/api/info" | jq -r '.data')
echo "   $PROFILE_INFO"
echo ""

echo "2. Simple query (shows I/O, CPU, and memory allocation):"
curl -s "$ENDPOINT/api/query" | jq '{
  threadType: .threadType,
  result: .data
}'
echo ""

echo "3. Multiple queries (3 sequential):"
curl -s "$ENDPOINT/api/multiple/3" | jq '{
  threadType: .threadType,
  result: .data
}'
echo ""

echo "4. CPU-intensive work (100ms):"
curl -s "$ENDPOINT/api/cpu/100" | jq '{
  threadType: .threadType,
  result: .data
}'
echo ""

echo "5. Stress test (5 queries + 50ms CPU):"
curl -s "$ENDPOINT/api/stress?queries=5&cpuMs=50" | jq '{
  threadType: .threadType,
  result: .data
}'
echo ""

echo "========================================="
echo "Performance Characteristics:"
echo "========================================="
echo ""
echo "Thread metrics:"
curl -s "$ENDPOINT/actuator/metrics/jvm.threads.live" | jq '{
  name: .name,
  value: .measurements[0].value,
  description: .description
}'
echo ""

echo "Memory usage (heap):"
curl -s "$ENDPOINT/actuator/metrics/jvm.memory.used?tag=area:heap" | jq '{
  name: .name,
  value: (.measurements[0].value / 1024 / 1024 | floor),
  unit: "MB"
}'
echo ""

echo "========================================="
echo "Demonstration complete!"
echo ""
echo "Try different profiles:"
echo "  LIGHT - Minimal load (10-50ms I/O)"
echo "  MEDIUM - Standard load (50-200ms I/O)"
echo "  HEAVY - Heavy load (100-500ms I/O)"
echo "  REALISTIC_MIXED - Real-world (I/O + CPU + memory)"
echo "  CPU_INTENSIVE - Heavy CPU (100-500ms CPU)"
echo "  EXTREME - Maximum stress (200-1000ms I/O + CPU + memory)"
echo ""
echo "Run application with profile:"
echo "  mvn spring-boot:run -Dspring-boot.run.arguments=\"--app.workload.profile=EXTREME\""
echo "========================================="
