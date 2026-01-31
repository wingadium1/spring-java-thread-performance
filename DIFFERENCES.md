# Key Implementation Differences

## Quick Reference: How Each Approach Handles Requests

### Traditional Spring MVC (spring-mvc-traditional)

**Port:** 8080

**Key Configuration:**
```java
// Standard Spring Boot with Spring MVC
@SpringBootApplication
public class TraditionalMvcApplication { }

// Standard Tomcat configuration
server.tomcat.threads.max=200
```

**Request Handling:**
- Each request uses one platform thread from Tomcat's thread pool
- Thread blocks during I/O operations (database calls)
- Limited by thread pool size (default 200 threads)
- Thread stack: ~1MB per thread

**Best For:**
- Low to medium concurrency (< 200 concurrent requests)
- Simple applications
- Teams familiar with traditional blocking I/O

---

### Virtual Threads (spring-virtual-threads)

**Port:** 8081

**Key Configuration:**
```java
@Bean
public TomcatProtocolHandlerCustomizer<?> protocolHandlerVirtualThreadExecutorCustomizer() {
    return protocolHandler -> {
        protocolHandler.setExecutor(Executors.newVirtualThreadPerTaskExecutor());
    };
}
```

**Request Handling:**
- Each request uses one virtual thread
- Virtual threads are managed by the JVM (Project Loom)
- Can handle millions of concurrent virtual threads
- Virtual thread stack: dynamically sized, much smaller than platform threads
- Still blocking calls, but cheap to block

**Best For:**
- High concurrency with blocking I/O
- Easy migration from Traditional MVC (code stays the same)
- When Java 21+ is available

---

### WebFlux (spring-webflux)

**Port:** 8082

**Key Configuration:**
```java
// Use WebFlux starter instead of Web
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-webflux</artifactId>
</dependency>

// Reactive endpoints return Mono/Flux
@GetMapping("/api/query")
public Mono<ApiResponse> simpleQuery() {
    return Mono.fromCallable(() -> {
        String result = databaseSimulator.executeQuery("simple-query");
        return new ApiResponse("Query executed", result);
    }).subscribeOn(Schedulers.boundedElastic());
}
```

**Request Handling:**
- Requests handled by small number of event loop threads (default: CPU cores)
- Non-blocking I/O model
- Blocking operations offloaded to bounded elastic scheduler
- Reactive streams (Mono, Flux)
- Backpressure support

**Best For:**
- Very high concurrency
- Microservices with async communication
- When team has reactive programming expertise
- True non-blocking I/O throughout the stack

---

## Performance Characteristics Comparison

| Metric | Traditional MVC | Virtual Threads | WebFlux |
|--------|----------------|-----------------|---------|
| **Thread Model** | Platform threads (1:1 with requests) | Virtual threads (many:few) | Event loop + workers |
| **Max Threads** | ~200 (configurable) | Millions | ~20-50 |
| **Memory per Thread** | ~1MB stack | ~KB stack | N/A (event loop) |
| **Context Switch Cost** | High | Low | Very Low |
| **Programming Model** | Synchronous/Blocking | Synchronous/Blocking | Asynchronous/Non-blocking |
| **Code Complexity** | Simple | Simple | Complex |
| **Learning Curve** | Easy | Easy | Steep |
| **I/O Model** | Blocking | Blocking (cheap) | Non-blocking |
| **Throughput (low load)** | Good | Good | Good |
| **Throughput (high load)** | Poor | Excellent | Excellent |
| **Latency (low load)** | Good | Good | Good |
| **Latency (high load)** | Poor | Good | Excellent |

---

## Code Differences

### Endpoint Definition

**Traditional MVC:**
```java
@GetMapping("/api/query")
public ApiResponse simpleQuery() {
    String result = databaseSimulator.executeQuery("simple-query");
    return new ApiResponse("Query executed", result);
}
```

**Virtual Threads:**
```java
@GetMapping("/api/query")
public ApiResponse simpleQuery() {
    // Same code as Traditional MVC!
    String result = databaseSimulator.executeQuery("simple-query");
    return new ApiResponse("Query executed", result);
}
```

**WebFlux:**
```java
@GetMapping("/api/query")
public Mono<ApiResponse> simpleQuery() {
    return Mono.fromCallable(() -> {
        String result = databaseSimulator.executeQuery("simple-query");
        return new ApiResponse("Query executed", result);
    }).subscribeOn(Schedulers.boundedElastic());
}
```

---

## Thread Information in Responses

**Traditional MVC:**
```json
{
  "message": "Query executed",
  "threadName": "http-nio-8080-exec-1",
  "threadType": "Platform",
  "data": "Result for 'simple-query' (took 106ms)"
}
```

**Virtual Threads:**
```json
{
  "message": "Query executed",
  "threadName": "",
  "threadType": "Virtual",
  "data": "Result for 'simple-query' (took 182ms)"
}
```

**WebFlux:**
```json
{
  "message": "Query executed",
  "threadName": "boundedElastic-1",
  "threadType": "Platform",
  "data": "Result for 'simple-query' (took 135ms)"
}
```

---

## When to Choose Each Approach

### Choose Traditional MVC when:
- Building simple CRUD applications
- Expected load < 200 concurrent users
- Team is unfamiliar with reactive programming
- Quick prototyping or MVPs
- Legacy codebase constraints

### Choose Virtual Threads when:
- Need high concurrency (1000+ concurrent users)
- Working with blocking I/O (databases, REST clients)
- Want easy migration from Traditional MVC
- Java 21+ is available
- Team prefers synchronous programming model
- **Recommended for most new projects on Java 21+**

### Choose WebFlux when:
- Need very high concurrency (10,000+ concurrent users)
- Building event-driven microservices
- Team has reactive programming expertise
- Full non-blocking stack is possible (DB, external services)
- Need backpressure support
- Building streaming applications

---

## Migration Path

### Traditional MVC → Virtual Threads
**Effort:** Minimal (configuration change only)

1. Upgrade to Java 21
2. Upgrade Spring Boot to 3.2+
3. Add `TomcatProtocolHandlerCustomizer` bean
4. No code changes required!

### Traditional MVC → WebFlux
**Effort:** High (complete rewrite)

1. Change dependency from `spring-boot-starter-web` to `spring-boot-starter-webflux`
2. Rewrite all endpoints to return `Mono<T>` or `Flux<T>`
3. Ensure all I/O operations are non-blocking
4. Update tests for reactive code
5. Team training on reactive programming

### Virtual Threads → Traditional MVC
**Effort:** Minimal (configuration change only)

1. Remove `TomcatProtocolHandlerCustomizer` bean
2. Can downgrade to Java 17 if needed

---

## Testing Each Approach

### Quick Verification
```bash
# Traditional MVC - should show "Platform" threads
curl http://localhost:8080/api/info | jq .threadType

# Virtual Threads - should show "Virtual" threads
curl http://localhost:8081/api/info | jq .threadType

# WebFlux - uses Platform threads but in event loop model
curl http://localhost:8082/api/info | jq .threadType
```

### Load Testing
```bash
# Light load - all should perform similarly
wrk -t4 -c100 -d30s http://localhost:8080/api/query
wrk -t4 -c100 -d30s http://localhost:8081/api/query
wrk -t4 -c100 -d30s http://localhost:8082/api/query

# Heavy load - Virtual Threads and WebFlux should excel
wrk -t8 -c1000 -d60s http://localhost:8080/api/query
wrk -t8 -c1000 -d60s http://localhost:8081/api/query
wrk -t8 -c1000 -d60s http://localhost:8082/api/query
```

---

## Common Misconceptions

### ❌ "Virtual Threads are just like async/await"
**Reality:** Virtual threads are still blocking, they're just very cheap to create and block. They don't require async programming.

### ❌ "WebFlux is always faster"
**Reality:** WebFlux shines with high concurrency and non-blocking I/O. For simple CRUD with low load, Traditional MVC might be faster.

### ❌ "Virtual Threads eliminate thread pools"
**Reality:** Virtual threads are scheduled on a pool of carrier (platform) threads. You still have thread scheduling, just managed by the JVM.

### ❌ "I need to rewrite my code for Virtual Threads"
**Reality:** Virtual threads work with existing blocking code. Migration is often just a configuration change.

---

## Further Reading

- [JEP 444: Virtual Threads](https://openjdk.org/jeps/444)
- [Spring Boot 3.2 Virtual Threads Support](https://spring.io/blog/2023/09/09/spring-boot-3-2-virtual-threads)
- [Project Reactor Documentation](https://projectreactor.io/docs)
- [Spring WebFlux Documentation](https://docs.spring.io/spring-framework/reference/web/webflux.html)
