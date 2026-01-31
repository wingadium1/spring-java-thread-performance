package com.performance.virtual;

import com.performance.common.DatabaseSimulator;
import org.springframework.boot.web.embedded.tomcat.TomcatProtocolHandlerCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.concurrent.Executors;

@Configuration
public class AppConfig {

    @Bean
    public DatabaseSimulator databaseSimulator() {
        return new DatabaseSimulator(50, 200);
    }

    /**
     * Configures Tomcat to use virtual threads for handling requests.
     * This is the key difference from traditional MVC - all request handling
     * will be done on virtual threads instead of platform threads.
     */
    @Bean
    public TomcatProtocolHandlerCustomizer<?> protocolHandlerVirtualThreadExecutorCustomizer() {
        return protocolHandler -> {
            protocolHandler.setExecutor(Executors.newVirtualThreadPerTaskExecutor());
        };
    }
}
