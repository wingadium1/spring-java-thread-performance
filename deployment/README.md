# Systemd Service Deployment Guide

## Prerequisites

1. Create a dedicated user for running the applications:
```bash
sudo useradd -r -s /bin/false springapp
```

2. Create application directory:
```bash
sudo mkdir -p /opt/spring-performance
sudo chown springapp:springapp /opt/spring-performance
```

## Deployment Steps

1. Copy JAR files to the server:
```bash
scp spring-mvc-traditional/target/*.jar user@server:/opt/spring-performance/
scp spring-virtual-threads/target/*.jar user@server:/opt/spring-performance/
scp spring-webflux/target/*.jar user@server:/opt/spring-performance/
```

2. Copy systemd service files:
```bash
sudo cp deployment/*.service /etc/systemd/system/
```

3. Set correct permissions:
```bash
sudo chown -R springapp:springapp /opt/spring-performance
sudo chmod 644 /etc/systemd/system/spring-*.service
```

4. Reload systemd and enable services:
```bash
sudo systemctl daemon-reload
sudo systemctl enable spring-mvc-traditional
sudo systemctl enable spring-virtual-threads
sudo systemctl enable spring-webflux
```

5. Start the services:
```bash
sudo systemctl start spring-mvc-traditional
sudo systemctl start spring-virtual-threads
sudo systemctl start spring-webflux
```

## Management Commands

### Check Status
```bash
sudo systemctl status spring-mvc-traditional
sudo systemctl status spring-virtual-threads
sudo systemctl status spring-webflux
```

### View Logs
```bash
sudo journalctl -u spring-mvc-traditional -f
sudo journalctl -u spring-virtual-threads -f
sudo journalctl -u spring-webflux -f
```

### Stop Services
```bash
sudo systemctl stop spring-mvc-traditional
sudo systemctl stop spring-virtual-threads
sudo systemctl stop spring-webflux
```

### Restart Services
```bash
sudo systemctl restart spring-mvc-traditional
sudo systemctl restart spring-virtual-threads
sudo systemctl restart spring-webflux
```

## Firewall Configuration

Allow access to the application ports:
```bash
sudo ufw allow 8080/tcp  # Traditional MVC
sudo ufw allow 8081/tcp  # Virtual Threads
sudo ufw allow 8082/tcp  # WebFlux
```

## Health Check

Verify the applications are running:
```bash
curl http://localhost:8080/actuator/health
curl http://localhost:8081/actuator/health
curl http://localhost:8082/actuator/health
```
