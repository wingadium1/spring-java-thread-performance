package com.performance.webflux;

import com.performance.common.DatabaseSimulator;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

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
}
