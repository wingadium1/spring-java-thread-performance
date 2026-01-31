package com.performance.common;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Random;
import java.util.concurrent.TimeUnit;

/**
 * Service that simulates database operations with configurable delay.
 * Used to simulate blocking I/O operations for performance testing.
 */
public class DatabaseSimulator {
    
    private static final Logger logger = LoggerFactory.getLogger(DatabaseSimulator.class);
    private static final Random random = new Random();
    
    private final long minDelayMs;
    private final long maxDelayMs;
    
    public DatabaseSimulator() {
        this(50, 200); // Default 50-200ms delay
    }
    
    public DatabaseSimulator(long minDelayMs, long maxDelayMs) {
        this.minDelayMs = minDelayMs;
        this.maxDelayMs = maxDelayMs;
    }
    
    /**
     * Simulates a blocking database query.
     * Blocks the current thread for a random duration between min and max delay.
     * 
     * @param queryName Name of the simulated query for logging
     * @return Simulated query result
     */
    public String executeQuery(String queryName) {
        long delay = minDelayMs + (long) (random.nextDouble() * (maxDelayMs - minDelayMs));
        
        try {
            Thread.sleep(delay);
            logger.debug("Executed query '{}' in {}ms on thread: {}", 
                queryName, delay, Thread.currentThread().getName());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            logger.error("Query interrupted: {}", queryName, e);
            throw new RuntimeException("Query interrupted", e);
        }
        
        return String.format("Result for '%s' (took %dms)", queryName, delay);
    }
    
    /**
     * Simulates a blocking database query with specific delay.
     * 
     * @param queryName Name of the simulated query
     * @param delayMs Specific delay in milliseconds
     * @return Simulated query result
     */
    public String executeQueryWithDelay(String queryName, long delayMs) {
        try {
            Thread.sleep(delayMs);
            logger.debug("Executed query '{}' in {}ms on thread: {}", 
                queryName, delayMs, Thread.currentThread().getName());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            logger.error("Query interrupted: {}", queryName, e);
            throw new RuntimeException("Query interrupted", e);
        }
        
        return String.format("Result for '%s' (took %dms)", queryName, delayMs);
    }
    
    /**
     * Simulates multiple sequential database queries.
     * 
     * @param count Number of queries to execute
     * @return Combined result
     */
    public String executeMultipleQueries(int count) {
        StringBuilder result = new StringBuilder();
        long totalTime = 0;
        
        for (int i = 0; i < count; i++) {
            long delay = minDelayMs + (long) (random.nextDouble() * (maxDelayMs - minDelayMs));
            try {
                Thread.sleep(delay);
                totalTime += delay;
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new RuntimeException("Query interrupted", e);
            }
        }
        
        logger.debug("Executed {} queries in {}ms on thread: {}", 
            count, totalTime, Thread.currentThread().getName());
        
        return String.format("Executed %d queries in %dms", count, totalTime);
    }
}
