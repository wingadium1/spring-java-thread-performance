package com.performance.virtual;

import com.performance.common.ApiResponse;
import com.performance.common.DatabaseSimulator;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api")
public class PerformanceController {

    @Autowired
    private DatabaseSimulator databaseSimulator;

    @GetMapping("/hello")
    public ApiResponse hello() {
        return new ApiResponse("Hello from Spring Boot with Virtual Threads", "No database call");
    }

    @GetMapping("/query")
    public ApiResponse simpleQuery() {
        String result = databaseSimulator.executeQuery("simple-query");
        return new ApiResponse("Query executed", result);
    }

    @GetMapping("/query/{delay}")
    public ApiResponse queryWithDelay(@PathVariable long delay) {
        String result = databaseSimulator.executeQueryWithDelay("custom-delay-query", delay);
        return new ApiResponse("Query with custom delay executed", result);
    }

    @GetMapping("/multiple/{count}")
    public ApiResponse multipleQueries(@PathVariable int count) {
        String result = databaseSimulator.executeMultipleQueries(count);
        return new ApiResponse("Multiple queries executed", result);
    }
    
    @GetMapping("/cpu/{durationMs}")
    public ApiResponse cpuIntensive(@PathVariable long durationMs) {
        String result = databaseSimulator.executeCpuIntensiveWork(durationMs);
        return new ApiResponse("CPU-intensive work completed", result);
    }
    
    @GetMapping("/stress")
    public ApiResponse stressTest(
            @RequestParam(defaultValue = "5") int queries,
            @RequestParam(defaultValue = "100") long cpuMs) {
        long startTime = System.currentTimeMillis();
        
        // Execute multiple queries (I/O + CPU + memory)
        String queryResult = databaseSimulator.executeMultipleQueries(queries);
        
        // Additional CPU work
        String cpuResult = databaseSimulator.executeCpuIntensiveWork(cpuMs);
        
        long totalTime = System.currentTimeMillis() - startTime;
        
        String combinedResult = String.format("Stress test completed in %dms. Queries: %s. CPU: %s", 
            totalTime, queryResult, cpuResult);
        
        return new ApiResponse("Stress test executed", combinedResult);
    }

    @GetMapping("/info")
    public ApiResponse info() {
        ApiResponse response = new ApiResponse();
        response.setMessage("Spring Boot with Virtual Threads (Java 21)");
        response.setData("Virtual threads handle blocking I/O efficiently. Profile: " + 
            databaseSimulator.getProfile().name());
        return response;
    }
}
