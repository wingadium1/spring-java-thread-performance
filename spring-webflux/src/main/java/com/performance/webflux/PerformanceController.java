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

    @GetMapping("/info")
    public Mono<ApiResponse> info() {
        ApiResponse response = new ApiResponse();
        response.setMessage("Spring WebFlux with Reactor Netty");
        response.setData("Reactive non-blocking I/O with event loop");
        return Mono.just(response);
    }
}
