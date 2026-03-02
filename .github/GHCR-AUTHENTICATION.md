# GitHub Container Registry (GHCR) Authentication Guide

This guide explains how to authenticate with GitHub Container Registry (ghcr.io) for building and pushing Docker images using Jib Maven plugin in GitHub Actions.

## Overview

The CI workflow (`ci.yml`) already includes Docker login configuration using the `docker/login-action@v3` which authenticates with GitHub Container Registry (ghcr.io) to push Docker images built by the Jib Maven plugin.

## Current Workflow Configuration

The workflow at `.github/workflows/ci.yml` includes:

```yaml
- name: Log in to GitHub Container Registry
  uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

This configuration:
- Uses the official Docker login action
- Authenticates with `ghcr.io` (GitHub Container Registry)
- Uses `github.actor` as the username (the user who triggered the workflow)
- Uses `GITHUB_TOKEN` for authentication (automatically provided by GitHub Actions)

## Authentication Methods

### Method 1: Using GITHUB_TOKEN (Recommended - Default)

**This is the simplest method and is already configured in the workflow.**

#### How It Works

- `GITHUB_TOKEN` is automatically provided by GitHub Actions to every workflow run
- No manual setup required
- Token has automatic permissions based on repository settings

#### Permissions Required

The workflow must have the `packages: write` permission. This is already configured in `ci.yml`:

```yaml
permissions:
  contents: read
  packages: write
```

#### Verification

1. Go to your repository **Settings** → **Actions** → **General**
2. Scroll to **Workflow permissions**
3. Ensure either:
   - "Read and write permissions" is selected, OR
   - "Read repository contents and packages permissions" is selected

#### Package Visibility

After the first successful push:
1. Go to your GitHub profile or organization
2. Click on **Packages** tab
3. Find your package (e.g., `spring-mvc-traditional`)
4. Click on **Package settings**
5. Under **Danger Zone**, you can:
   - Change package visibility (Public/Private)
   - Link to the repository
   - Manage access

### Method 2: Using Personal Access Token (PAT) - Alternative

Use this method if:
- You need fine-grained control over permissions
- You're pushing to a different organization's registry
- `GITHUB_TOKEN` permissions are restricted in your organization

#### Step 1: Generate Personal Access Token

1. Go to **GitHub** → **Settings** (your profile settings)
2. Navigate to **Developer settings** → **Personal access tokens** → **Tokens (classic)**
3. Click **Generate new token** → **Generate new token (classic)**
4. Configure the token:
   - **Note**: "GitHub Actions - GHCR Push"
   - **Expiration**: Choose appropriate expiration (90 days, 1 year, or custom)
   - **Scopes**: Select the following:
     - ✅ `write:packages` - Upload packages to GitHub Package Registry
     - ✅ `read:packages` - Download packages from GitHub Package Registry
     - ✅ `delete:packages` - Delete packages from GitHub Package Registry (optional)
5. Click **Generate token**
6. **Copy the token immediately** (you won't be able to see it again)

#### Step 2: Add Token to Repository Secrets

1. Go to your repository on GitHub
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Configure:
   - **Name**: `GHCR_TOKEN` or `PAT_TOKEN`
   - **Value**: Paste the personal access token you just generated
5. Click **Add secret**

#### Step 3: Update Workflow to Use PAT

Edit `.github/workflows/ci.yml` and change the Docker login step:

```yaml
- name: Log in to GitHub Container Registry
  uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GHCR_TOKEN }}  # Changed from GITHUB_TOKEN
```

#### Step 4: Update Jib Configuration

Also update the Jib build step to use the PAT:

```yaml
- name: Build and push images with Jib
  env:
    VERSION_TAG: ${{ steps.tags.outputs.version }}
    SHA_TAG: ${{ steps.tags.outputs.sha }}
  run: |
    for module in spring-mvc-traditional spring-virtual-threads spring-webflux; do
      echo "Building and pushing ${module}..."
      
      mvn -pl ${module} jib:build \
        -Djib.to.image="${{ env.IMAGE_PREFIX }}/${module}" \
        -Djib.to.tags="${VERSION_TAG},${SHA_TAG}" \
        -Djib.to.auth.username="${{ github.actor }}" \
        -Djib.to.auth.password="${{ secrets.GHCR_TOKEN }}"  # Changed from GITHUB_TOKEN
    done
```

## How Jib Authentication Works

The Jib Maven plugin authenticates with the container registry using the credentials provided via command-line parameters:

```bash
mvn jib:build \
  -Djib.to.image="ghcr.io/owner/repo/image-name" \
  -Djib.to.auth.username="username" \
  -Djib.to.auth.password="token"
```

The `docker/login-action` step creates a Docker configuration file that Jib can also use, but we explicitly pass credentials to ensure authentication works correctly.

## Verifying the Setup

### 1. Check Workflow Permissions

```bash
# View the workflow file
cat .github/workflows/ci.yml | grep -A 3 "permissions:"
```

Expected output:
```yaml
permissions:
  contents: read
  packages: write
```

### 2. Trigger a Workflow Run

Push to `main` or `develop` branch to trigger the CI workflow:

```bash
git checkout main
git commit --allow-empty -m "Test GHCR push"
git push origin main
```

### 3. Monitor the Workflow

1. Go to **Actions** tab in your repository
2. Click on the latest workflow run
3. Check the "Build and push images with Jib" step
4. Look for successful push messages

### 4. Verify Images in GHCR

After successful workflow run:

```bash
# Pull the image to verify it's available
docker pull ghcr.io/wingadium1/spring-java-thread-performance/spring-mvc-traditional:latest

# Or check via GitHub UI
# Visit: https://github.com/orgs/wingadium1/packages
```

## Making Packages Public

By default, packages pushed to GHCR are private. To make them public:

1. Go to your package page:
   - For user: `https://github.com/users/YOUR_USERNAME/packages/container/PACKAGE_NAME`
   - For org: `https://github.com/orgs/YOUR_ORG/packages/container/PACKAGE_NAME`
2. Click **Package settings** (right sidebar)
3. Scroll to **Danger Zone** → **Change package visibility**
4. Click **Change visibility**
5. Select **Public**
6. Type the package name to confirm
7. Click **I understand, change package visibility**

## Pulling Images from GHCR

### Public Images

```bash
# No authentication needed for public images
docker pull ghcr.io/wingadium1/spring-java-thread-performance/spring-mvc-traditional:latest
```

### Private Images

```bash
# Login first
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Or with PAT
echo $PAT_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Then pull
docker pull ghcr.io/wingadium1/spring-java-thread-performance/spring-mvc-traditional:latest
```

## Local Development - Pushing to GHCR

If you want to push images to GHCR from your local machine:

### 1. Generate a PAT

Follow the same steps as "Method 2" above to generate a Personal Access Token with `write:packages` scope.

### 2. Login to GHCR

```bash
# Login with your PAT
echo YOUR_PAT_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin
```

### 3. Build and Push with Jib

```bash
# Build and push a single module
cd spring-mvc-traditional
mvn clean package jib:build \
  -Ddocker.registry=ghcr.io/ \
  -Djib.to.auth.username=YOUR_USERNAME \
  -Djib.to.auth.password=YOUR_PAT_TOKEN

# Or build and push all modules
mvn clean package jib:build \
  -Ddocker.registry=ghcr.io/ \
  -Djib.to.auth.username=YOUR_USERNAME \
  -Djib.to.auth.password=YOUR_PAT_TOKEN
```

## Troubleshooting

### Error: "insufficient_scope: authorization failed"

**Cause**: The token doesn't have `write:packages` permission.

**Solution**:
1. If using `GITHUB_TOKEN`: Check workflow permissions in repository settings
2. If using PAT: Regenerate token with correct scopes

### Error: "denied: permission_denied: write_package"

**Cause**: The GitHub Actions workflow doesn't have permission to write packages.

**Solution**:
1. Go to **Repository Settings** → **Actions** → **General**
2. Under **Workflow permissions**, select "Read and write permissions"
3. Click **Save**

### Error: "unauthorized: authentication required"

**Cause**: Docker login failed or credentials not properly configured.

**Solution**:
1. Verify the `docker/login-action` step completed successfully
2. Check that credentials are being passed to Jib correctly
3. Ensure the registry URL is exactly `ghcr.io`

### Images not appearing in GitHub Packages

**Cause**: Package might be created but not linked to the repository.

**Solution**:
1. Go to your GitHub profile → **Packages** tab
2. Find your package
3. Click **Package settings** → **Connect repository**
4. Select your repository

### "Name unknown: repository name not known to registry"

**Cause**: The image name/repository path is incorrect.

**Solution**:
- Verify the image name format: `ghcr.io/USERNAME_OR_ORG/REPO_NAME/IMAGE_NAME`
- Ensure lowercase names (GHCR requires lowercase)
- For this project: `ghcr.io/wingadium1/spring-java-thread-performance/spring-mvc-traditional`

## Best Practices

1. **Use GITHUB_TOKEN for CI/CD**: It's automatically managed and scoped to the repository
2. **Use PAT for local development**: Keep it secure and don't commit it to the repository
3. **Set token expiration**: Use shortest expiration possible for PATs
4. **Rotate tokens regularly**: Update PATs before they expire
5. **Use repository secrets**: Never hardcode tokens in workflows or code
6. **Make packages public if appropriate**: Easier to pull without authentication
7. **Link packages to repositories**: Helps with discoverability and access management
8. **Use semantic versioning**: Tag images with meaningful versions (e.g., `v1.0.0`, `latest`, `develop`)

## Security Considerations

1. **Never commit tokens**: Add `*.token` to `.gitignore`
2. **Limit token scope**: Only grant necessary permissions
3. **Use fine-grained tokens**: Use Fine-grained Personal Access Tokens when available
4. **Monitor token usage**: Regularly audit token usage in GitHub settings
5. **Revoke unused tokens**: Remove tokens that are no longer needed
6. **Use organization secrets**: For shared resources, use organization-level secrets

## Additional Resources

- [GitHub Packages Documentation](https://docs.github.com/en/packages)
- [Working with the Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Docker Login Action](https://github.com/docker/login-action)
- [Jib Maven Plugin](https://github.com/GoogleContainerTools/jib/tree/master/jib-maven-plugin)
- [GitHub Actions Permissions](https://docs.github.com/en/actions/security-guides/automatic-token-authentication)

## Summary

**For most users**, the default configuration using `GITHUB_TOKEN` is sufficient:
- ✅ Already configured in the workflow
- ✅ No manual setup required
- ✅ Automatic permission management
- ✅ Secure by default

**Only use a Personal Access Token if**:
- ❗ You need to push from outside GitHub Actions (local development)
- ❗ Your organization restricts `GITHUB_TOKEN` permissions
- ❗ You need to push to a different organization's registry

The current workflow is production-ready and will work out of the box for pushing images to GHCR! 🎉
