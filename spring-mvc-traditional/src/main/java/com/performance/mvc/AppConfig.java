package com.performance.mvc;

import com.performance.common.DatabaseSimulator;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class AppConfig {

    @Bean
    public DatabaseSimulator databaseSimulator() {
        return new DatabaseSimulator(50, 200);
    }
}
