# Docker Images on GitHub Container Registry

This project automatically builds and publishes Docker images to GitHub Container Registry (ghcr.io) on every push to `main` or `develop` branches, and on tagged releases.

## Available Images

Three Spring Boot applications are available as Docker images:

| Application | Image URL | Description |
|-------------|-----------|-------------|
| **Spring MVC Traditional** | `ghcr.io/wingadium1/spring-java-thread-performance/spring-mvc-traditional` | Traditional blocking I/O with Spring MVC |
| **Spring Virtual Threads** | `ghcr.io/wingadium1/spring-java-thread-performance/spring-virtual-threads` | Java 21 Virtual Threads |
| **Spring WebFlux** | `ghcr.io/wingadium1/spring-java-thread-performance/spring-webflux` | Reactive programming with WebFlux |

## Image Tags

Images are tagged with the following conventions:

- `latest` - Latest build from `main` branch
- `develop` - Latest build from `develop` branch
- `v1.0.0` - Semantic version tags (when tagged in Git)
- `abc1234` - Short commit SHA (7 characters)

## Pulling Images

### Public Images

Images are publicly available and can be pulled without authentication:

```bash
# Pull latest version
docker pull ghcr.io/wingadium1/spring-java-thread-performance/spring-mvc-traditional:latest
docker pull ghcr.io/wingadium1/spring-java-thread-performance/spring-virtual-threads:latest
docker pull ghcr.io/wingadium1/spring-java-thread-performance/spring-webflux:latest

# Pull specific version
docker pull ghcr.io/wingadium1/spring-java-thread-performance/spring-mvc-traditional:v1.0.0

# Pull by commit SHA
docker pull ghcr.io/wingadium1/spring-java-thread-performance/spring-mvc-traditional:abc1234
```

### Running Containers

```bash
# Run Spring MVC Traditional
docker run -d -p 8080:8080 \
  --name spring-mvc \
  ghcr.io/wingadium1/spring-java-thread-performance/spring-mvc-traditional:latest

# Run Spring Virtual Threads
docker run -d -p 8081:8080 \
  --name spring-virtual-threads \
  ghcr.io/wingadium1/spring-java-thread-performance/spring-virtual-threads:latest

# Run Spring WebFlux
docker run -d -p 8082:8080 \
  --name spring-webflux \
  ghcr.io/wingadium1/spring-java-thread-performance/spring-webflux:latest
```

### With Environment Variables

```bash
docker run -d -p 8080:8080 \
  -e SPRING_PROFILES_ACTIVE=production \
  -e SERVER_PORT=8080 \
  ghcr.io/wingadium1/spring-java-thread-performance/spring-mvc-traditional:latest
```

### With Resource Limits

```bash
docker run -d -p 8080:8080 \
  --memory="2g" \
  --cpus="2" \
  ghcr.io/wingadium1/spring-java-thread-performance/spring-mvc-traditional:latest
```

## Using with Docker Compose

Create a `docker-compose.yml` file:

```yaml
version: '3.8'

services:
  spring-mvc:
    image: ghcr.io/wingadium1/spring-java-thread-performance/spring-mvc-traditional:latest
    ports:
      - "8080:8080"
    environment:
      - SPRING_PROFILES_ACTIVE=production
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G

  spring-virtual-threads:
    image: ghcr.io/wingadium1/spring-java-thread-performance/spring-virtual-threads:latest
    ports:
      - "8081:8080"
    environment:
      - SPRING_PROFILES_ACTIVE=production
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G

  spring-webflux:
    image: ghcr.io/wingadium1/spring-java-thread-performance/spring-webflux:latest
    ports:
      - "8082:8080"
    environment:
      - SPRING_PROFILES_ACTIVE=production
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
```

Run with:

```bash
docker-compose up -d
```

## Using in Kubernetes

### Direct Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spring-mvc-traditional
spec:
  replicas: 3
  selector:
    matchLabels:
      app: spring-mvc-traditional
  template:
    metadata:
      labels:
        app: spring-mvc-traditional
    spec:
      containers:
      - name: spring-mvc-traditional
        image: ghcr.io/wingadium1/spring-java-thread-performance/spring-mvc-traditional:latest
        ports:
        - containerPort: 8080
        resources:
          limits:
            memory: "2Gi"
            cpu: "2"
          requests:
            memory: "512Mi"
            cpu: "500m"
```

### Using Helm

If you have Helm charts, update `values.yaml`:

```yaml
image:
  repository: ghcr.io/wingadium1/spring-java-thread-performance/spring-mvc-traditional
  tag: latest
  pullPolicy: Always
```

## Building Images Locally

If you want to build images locally with the same configuration:

### Build for Local Docker

```bash
# Build all images locally
mvn clean package jib:dockerBuild

# Build specific module
mvn -pl spring-mvc-traditional jib:dockerBuild
```

### Build and Push to GHCR

```bash
# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Build and push
mvn clean package jib:build \
  -Ddocker.registry=ghcr.io/ \
  -Ddocker.image.prefix=wingadium1/spring-java-thread-performance
```

## Image Metadata

All images include OCI labels for better documentation:

- `org.opencontainers.image.source` - GitHub repository URL
- `org.opencontainers.image.description` - Application description
- `org.opencontainers.image.licenses` - License type

View image metadata:

```bash
docker inspect ghcr.io/wingadium1/spring-java-thread-performance/spring-mvc-traditional:latest
```

## CI/CD Integration

Images can be built and pushed from CI/CD pipelines or manually using Jib commands in this guide.

### Typical CI/CD Triggers

- **Push to main/develop** - Builds and tags as `latest` or `develop`
- **Git tags (v*)** - Builds and tags with version number
- **Pull requests** - Build validation without publishing

## Troubleshooting

### Authentication Issues

If you have issues pulling images, make sure they are set to public visibility:

1. Go to https://github.com/wingadium1?tab=packages
2. Select the package
3. Go to "Package settings"
4. Under "Danger Zone", change visibility to "Public"

### Image Not Found

Check that your CI pipeline has completed successfully:
- Go to the repository's **Actions** tab
- Look for the latest image build pipeline run
- Check the logs if there are any errors

### Using in Air-Gapped Environments

To use images in environments without internet access:

```bash
# Pull and save images
docker pull ghcr.io/wingadium1/spring-java-thread-performance/spring-mvc-traditional:latest
docker save ghcr.io/wingadium1/spring-java-thread-performance/spring-mvc-traditional:latest > spring-mvc.tar

# Transfer to air-gapped environment and load
docker load < spring-mvc.tar
```

## Related Documentation

- [GitHub Container Registry Documentation](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Jib Maven Plugin Documentation](https://github.com/GoogleContainerTools/jib/tree/master/jib-maven-plugin)
- [Main README](../README.md)

## Support

For issues related to:
- **Image builds**: Check the GitHub Actions workflow logs
- **Runtime issues**: Check the application logs with `docker logs <container-name>`
- **General questions**: Open an issue in the GitHub repository
