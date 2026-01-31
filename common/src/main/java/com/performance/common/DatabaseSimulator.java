package com.performance.common;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.concurrent.TimeUnit;

/**
 * Service that simulates database operations with configurable delay and CPU/memory load.
 * Used to simulate blocking I/O operations and resource-intensive processing for performance testing.
 * 
 * Supports different workload profiles to test system behavior under various scenarios:
 * - I/O-bound: Mostly waiting (simulates network/disk I/O)
 * - CPU-bound: Processing results (simulates query processing, JSON parsing, etc.)
 * - Memory-bound: Large result sets (simulates fetching and holding data)
 * - Mixed: Realistic combination of all three
 */
public class DatabaseSimulator {
    
    private static final Logger logger = LoggerFactory.getLogger(DatabaseSimulator.class);
    private static final Random random = new Random();
    
    private final long minDelayMs;
    private final long maxDelayMs;
    private final WorkloadProfile profile;
    
    public enum WorkloadProfile {
        /** Light I/O only - 10-50ms delay, minimal CPU/memory */
        LIGHT(10, 50, 0, 0),
        /** Medium I/O - 50-200ms delay, minimal CPU/memory */
        MEDIUM(50, 200, 0, 0),
        /** Heavy I/O - 100-500ms delay, minimal CPU/memory */
        HEAVY(100, 500, 0, 0),
        /** I/O + CPU - 50-200ms delay + 10-50ms CPU work */
        IO_PLUS_CPU(50, 200, 10, 50),
        /** I/O + Memory - 50-200ms delay + 1-5MB allocations */
        IO_PLUS_MEMORY(50, 200, 0, 0, 1024 * 1024, 5 * 1024 * 1024),
        /** Extreme - 200-1000ms delay + CPU + memory */
        EXTREME(200, 1000, 50, 200, 5 * 1024 * 1024, 10 * 1024 * 1024),
        /** CPU intensive - minimal I/O, heavy computation */
        CPU_INTENSIVE(10, 50, 100, 500),
        /** Realistic mixed - simulates real DB queries with parsing */
        REALISTIC_MIXED(50, 200, 20, 100, 512 * 1024, 2 * 1024 * 1024);
        
        final long minIoMs;
        final long maxIoMs;
        final long minCpuMs;
        final long maxCpuMs;
        final long minMemoryBytes;
        final long maxMemoryBytes;
        
        WorkloadProfile(long minIoMs, long maxIoMs, long minCpuMs, long maxCpuMs) {
            this(minIoMs, maxIoMs, minCpuMs, maxCpuMs, 0, 0);
        }
        
        WorkloadProfile(long minIoMs, long maxIoMs, long minCpuMs, long maxCpuMs, 
                       long minMemoryBytes, long maxMemoryBytes) {
            this.minIoMs = minIoMs;
            this.maxIoMs = maxIoMs;
            this.minCpuMs = minCpuMs;
            this.maxCpuMs = maxCpuMs;
            this.minMemoryBytes = minMemoryBytes;
            this.maxMemoryBytes = maxMemoryBytes;
        }
    }
    
    public DatabaseSimulator() {
        this(50, 200, WorkloadProfile.MEDIUM);
    }
    
    public DatabaseSimulator(WorkloadProfile profile) {
        this.minDelayMs = profile.minIoMs;
        this.maxDelayMs = profile.maxIoMs;
        this.profile = profile;
    }
    
    public DatabaseSimulator(long minDelayMs, long maxDelayMs) {
        this(minDelayMs, maxDelayMs, WorkloadProfile.MEDIUM);
    }
    
    public DatabaseSimulator(long minDelayMs, long maxDelayMs, WorkloadProfile profile) {
        this.minDelayMs = minDelayMs;
        this.maxDelayMs = maxDelayMs;
        this.profile = profile;
    }
    
    /**
     * Simulates a blocking database query with I/O, CPU, and memory work.
     * Blocks the current thread for a random duration between min and max delay.
     * 
     * @param queryName Name of the simulated query for logging
     * @return Simulated query result
     */
    public String executeQuery(String queryName) {
        long startTime = System.currentTimeMillis();
        
        // 1. Simulate I/O wait (network/disk latency)
        long ioDelay = minDelayMs + (long) (random.nextDouble() * (maxDelayMs - minDelayMs));
        try {
            Thread.sleep(ioDelay);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            logger.error("Query interrupted during I/O: {}", queryName, e);
            throw new RuntimeException("Query interrupted", e);
        }
        
        // 2. Simulate CPU work (query processing, result parsing)
        long cpuWork = simulateCpuWork();
        
        // 3. Simulate memory allocation (result set)
        Object resultSet = simulateMemoryAllocation();
        
        long totalTime = System.currentTimeMillis() - startTime;
        
        logger.debug("Executed query '{}' in {}ms (I/O: {}ms, CPU: {}ms) on thread: {}", 
            queryName, totalTime, ioDelay, cpuWork, Thread.currentThread().getName());
        
        // Keep result set in scope to prevent early GC
        int resultSize = resultSet != null ? ((List<?>) resultSet).size() : 0;
        
        return String.format("Result for '%s' (took %dms, I/O: %dms, CPU: %dms, rows: %d)", 
            queryName, totalTime, ioDelay, cpuWork, resultSize);
    }
    
    /**
     * Simulates CPU-intensive work like query processing, JSON parsing, or data transformation.
     * @return Time spent in CPU work (ms)
     */
    private long simulateCpuWork() {
        if (profile.minCpuMs == 0 && profile.maxCpuMs == 0) {
            return 0;
        }
        
        long targetCpuMs = profile.minCpuMs + 
            (long) (random.nextDouble() * (profile.maxCpuMs - profile.minCpuMs));
        
        long startTime = System.currentTimeMillis();
        long endTime = startTime + targetCpuMs;
        
        // Perform actual CPU work (not just sleep)
        // This simulates query result processing, parsing, serialization, etc.
        long result = 0;
        while (System.currentTimeMillis() < endTime) {
            // CPU-intensive operations: hashing, string manipulation
            for (int i = 0; i < 1000; i++) {
                result += String.valueOf(random.nextInt()).hashCode();
            }
        }
        
        // Prevent optimization
        if (result == Long.MAX_VALUE) {
            logger.trace("Unlikely event: {}", result);
        }
        
        return System.currentTimeMillis() - startTime;
    }
    
    /**
     * Simulates memory allocation for result sets.
     * @return Allocated object (List simulating result set)
     */
    private Object simulateMemoryAllocation() {
        if (profile.minMemoryBytes == 0 && profile.maxMemoryBytes == 0) {
            return new ArrayList<>(0);
        }
        
        long targetBytes = profile.minMemoryBytes + 
            (long) (random.nextDouble() * (profile.maxMemoryBytes - profile.minMemoryBytes));
        
        // Simulate result set: each row is approximately 100 bytes
        int rowCount = (int) (targetBytes / 100);
        List<String> resultSet = new ArrayList<>(rowCount);
        
        for (int i = 0; i < rowCount; i++) {
            // Each row contains some data (simulating columns)
            resultSet.add(String.format("Row-%d-Data-%s", i, random.nextInt(10000)));
        }
        
        return resultSet;
    }
    
    /**
     * Simulates a blocking database query with specific delay.
     * 
     * @param queryName Name of the simulated query
     * @param delayMs Specific delay in milliseconds
     * @return Simulated query result
     */
    public String executeQueryWithDelay(String queryName, long delayMs) {
        long startTime = System.currentTimeMillis();
        
        try {
            Thread.sleep(delayMs);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            logger.error("Query interrupted: {}", queryName, e);
            throw new RuntimeException("Query interrupted", e);
        }
        
        // Add CPU work even with custom delay
        long cpuWork = simulateCpuWork();
        
        long totalTime = System.currentTimeMillis() - startTime;
        
        logger.debug("Executed query '{}' in {}ms on thread: {}", 
            queryName, totalTime, Thread.currentThread().getName());
        
        return String.format("Result for '%s' (took %dms)", queryName, totalTime);
    }
    
    /**
     * Simulates multiple sequential database queries.
     * 
     * @param count Number of queries to execute
     * @return Combined result
     */
    public String executeMultipleQueries(int count) {
        long startTime = System.currentTimeMillis();
        long totalIoTime = 0;
        long totalCpuTime = 0;
        int totalRows = 0;
        
        for (int i = 0; i < count; i++) {
            long ioDelay = minDelayMs + (long) (random.nextDouble() * (maxDelayMs - minDelayMs));
            try {
                Thread.sleep(ioDelay);
                totalIoTime += ioDelay;
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new RuntimeException("Query interrupted", e);
            }
            
            totalCpuTime += simulateCpuWork();
            Object resultSet = simulateMemoryAllocation();
            if (resultSet != null) {
                totalRows += ((List<?>) resultSet).size();
            }
        }
        
        long totalTime = System.currentTimeMillis() - startTime;
        
        logger.debug("Executed {} queries in {}ms (I/O: {}ms, CPU: {}ms) on thread: {}", 
            count, totalTime, totalIoTime, totalCpuTime, Thread.currentThread().getName());
        
        return String.format("Executed %d queries in %dms (I/O: %dms, CPU: %dms, total rows: %d)", 
            count, totalTime, totalIoTime, totalCpuTime, totalRows);
    }
    
    /**
     * Simulates a CPU-intensive operation (query planning, result processing).
     * 
     * @param durationMs Target duration for CPU work
     * @return Result description
     */
    public String executeCpuIntensiveWork(long durationMs) {
        long startTime = System.currentTimeMillis();
        long endTime = startTime + durationMs;
        
        long operations = 0;
        while (System.currentTimeMillis() < endTime) {
            // Simulate data processing, hashing, encoding
            for (int i = 0; i < 10000; i++) {
                operations += String.valueOf(random.nextLong()).hashCode();
            }
        }
        
        long actualTime = System.currentTimeMillis() - startTime;
        
        logger.debug("Executed CPU-intensive work for {}ms (target: {}ms) on thread: {}", 
            actualTime, durationMs, Thread.currentThread().getName());
        
        return String.format("CPU work completed in %dms (%d operations)", actualTime, operations);
    }
    
    /**
     * Get current workload profile.
     */
    public WorkloadProfile getProfile() {
        return profile;
    }
}
