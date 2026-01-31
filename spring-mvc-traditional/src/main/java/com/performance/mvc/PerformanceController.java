package com.performance.mvc;

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
        return new ApiResponse("Hello from Traditional Spring MVC", "No database call");
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

    @GetMapping("/info")
    public ApiResponse info() {
        ApiResponse response = new ApiResponse();
        response.setMessage("Traditional Spring MVC with Tomcat");
        response.setData("Blocking I/O with platform threads");
        return response;
    }
}
