package com.performance.common;

/**
 * Common response model for API endpoints.
 */
public class ApiResponse {
    
    private String message;
    private String threadName;
    private String threadType;
    private long timestamp;
    private String data;
    
    public ApiResponse() {
        this.timestamp = System.currentTimeMillis();
        Thread currentThread = Thread.currentThread();
        this.threadName = currentThread.getName();
        this.threadType = currentThread.isVirtual() ? "Virtual" : "Platform";
    }
    
    public ApiResponse(String message, String data) {
        this();
        this.message = message;
        this.data = data;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public String getThreadName() {
        return threadName;
    }

    public void setThreadName(String threadName) {
        this.threadName = threadName;
    }

    public String getThreadType() {
        return threadType;
    }

    public void setThreadType(String threadType) {
        this.threadType = threadType;
    }

    public long getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(long timestamp) {
        this.timestamp = timestamp;
    }

    public String getData() {
        return data;
    }

    public void setData(String data) {
        this.data = data;
    }
}
