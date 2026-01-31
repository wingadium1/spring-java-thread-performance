package com.performance.virtual;

import com.performance.common.DatabaseSimulator;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.embedded.tomcat.TomcatProtocolHandlerCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.concurrent.Executors;

@Configuration
public class AppConfig {

    @Value("${app.workload.profile:MEDIUM}")
    private String workloadProfile;

    @Bean
    public DatabaseSimulator databaseSimulator() {
        DatabaseSimulator.WorkloadProfile profile;
        try {
            profile = DatabaseSimulator.WorkloadProfile.valueOf(workloadProfile.toUpperCase());
        } catch (IllegalArgumentException e) {
            profile = DatabaseSimulator.WorkloadProfile.MEDIUM;
        }
        return new DatabaseSimulator(profile);
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
