package com.performance.webflux;

import com.performance.common.ApiResponse;
import com.performance.common.DatabaseSimulator;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

@RestController
@RequestMapping("/api")
public class PerformanceController {

    @Autowired
    private DatabaseSimulator databaseSimulator;

    @GetMapping("/hello")
    public Mono<ApiResponse> hello() {
        return Mono.just(new ApiResponse("Hello from Spring WebFlux", "No database call"));
    }

    @GetMapping("/query")
    public Mono<ApiResponse> simpleQuery() {
        // Execute blocking call on boundedElastic scheduler to avoid blocking event loop
        return Mono.fromCallable(() -> {
            String result = databaseSimulator.executeQuery("simple-query");
            return new ApiResponse("Query executed", result);
        }).subscribeOn(Schedulers.boundedElastic());
    }

    @GetMapping("/query/{delay}")
    public Mono<ApiResponse> queryWithDelay(@PathVariable long delay) {
        return Mono.fromCallable(() -> {
            String result = databaseSimulator.executeQueryWithDelay("custom-delay-query", delay);
            return new ApiResponse("Query with custom delay executed", result);
        }).subscribeOn(Schedulers.boundedElastic());
    }

    @GetMapping("/multiple/{count}")
    public Mono<ApiResponse> multipleQueries(@PathVariable int count) {
        return Mono.fromCallable(() -> {
            String result = databaseSimulator.executeMultipleQueries(count);
            return new ApiResponse("Multiple queries executed", result);
        }).subscribeOn(Schedulers.boundedElastic());
    }
    
    @GetMapping("/cpu/{durationMs}")
    public Mono<ApiResponse> cpuIntensive(@PathVariable long durationMs) {
        return Mono.fromCallable(() -> {
            String result = databaseSimulator.executeCpuIntensiveWork(durationMs);
            return new ApiResponse("CPU-intensive work completed", result);
        }).subscribeOn(Schedulers.boundedElastic());
    }
    
    @GetMapping("/stress")
    public Mono<ApiResponse> stressTest(
            @RequestParam(defaultValue = "5") int queries,
            @RequestParam(defaultValue = "100") long cpuMs) {
        return Mono.fromCallable(() -> {
            long startTime = System.currentTimeMillis();
            
            // Execute multiple queries (I/O + CPU + memory)
            String queryResult = databaseSimulator.executeMultipleQueries(queries);
            
            // Additional CPU work
            String cpuResult = databaseSimulator.executeCpuIntensiveWork(cpuMs);
            
            long totalTime = System.currentTimeMillis() - startTime;
            
            String combinedResult = String.format("Stress test completed in %dms. Queries: %s. CPU: %s", 
                totalTime, queryResult, cpuResult);
            
            return new ApiResponse("Stress test executed", combinedResult);
        }).subscribeOn(Schedulers.boundedElastic());
    }

    @GetMapping("/info")
    public Mono<ApiResponse> info() {
        ApiResponse response = new ApiResponse();
        response.setMessage("Spring WebFlux with Reactor Netty");
        response.setData("Reactive non-blocking I/O with event loop. Profile: " + 
            databaseSimulator.getProfile().name());
        return Mono.just(response);
    }
}
