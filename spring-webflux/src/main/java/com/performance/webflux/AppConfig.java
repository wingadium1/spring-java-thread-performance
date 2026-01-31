package com.performance.webflux;

import com.performance.common.DatabaseSimulator;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class AppConfig {

    private static final Logger logger = LoggerFactory.getLogger(AppConfig.class);

    @Value("${app.workload.profile:MEDIUM}")
    private String workloadProfile;

    @Bean
    public DatabaseSimulator databaseSimulator() {
        DatabaseSimulator.WorkloadProfile profile;
        try {
            profile = DatabaseSimulator.WorkloadProfile.valueOf(workloadProfile.toUpperCase());
            logger.info("Using workload profile: {}", profile);
        } catch (IllegalArgumentException e) {
            logger.warn("Invalid workload profile '{}', defaulting to MEDIUM", workloadProfile);
            profile = DatabaseSimulator.WorkloadProfile.MEDIUM;
        }
        return new DatabaseSimulator(profile);
    }
}
