# Quick Start: GitHub Container Registry (GHCR) Setup

**TL;DR**: The workflow is already configured! You likely don't need to do anything. 🎉

## Current Status ✅

Your repository already has:
- ✅ Docker login action configured (`docker/login-action@v3`)
- ✅ Jib Maven plugin setup in `pom.xml`
- ✅ Automatic image pushing to `ghcr.io`
- ✅ Proper permissions (`packages: write`)
- ✅ Configured for self-hosted runners (`runs-on: self-hosted`)

> **Using Self-Hosted Runner?** See [SELF-HOSTED-RUNNER-SETUP.md](SELF-HOSTED-RUNNER-SETUP.md) for complete setup guide!

## What You Need to Know

### 1. The workflow uses `GITHUB_TOKEN` (automatic, no setup needed)

The CI workflow at `.github/workflows/ci.yml` uses `GITHUB_TOKEN` which is:
- ✅ Automatically provided by GitHub Actions
- ✅ No manual configuration required
- ✅ Scoped to your repository
- ✅ Already has the right permissions

### 2. Images are automatically pushed on every commit

When you push to `main` or `develop`:
- 📦 Images are built with Jib
- 🚀 Images are pushed to `ghcr.io/wingadium1/spring-java-thread-performance/`
- 🏷️ Tagged with `latest` (main), `develop`, and commit SHA

### 3. You only need a Personal Access Token (PAT) for local development

If you want to push images from your local machine (not GitHub Actions):

**Quick Steps:**
1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Generate new token (classic) with `write:packages` scope
3. Save the token securely
4. Use it to login locally:
   ```bash
   echo YOUR_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin
   ```

## Verifying It Works

### Check Workflow Permissions
1. Go to your repository **Settings** → **Actions** → **General**
2. Under "Workflow permissions", ensure "Read and write permissions" is selected

### Trigger a Build
```bash
git commit --allow-empty -m "Test GHCR push"
git push origin main
```

### Check Your Packages
After the workflow completes:
- Visit: https://github.com/wingadium1?tab=packages
- You should see your images listed

### Make Images Public (Optional)
1. Go to your package on GitHub
2. Click **Package settings**
3. Change visibility to **Public**
4. Now anyone can pull without authentication!

## Pull Your Images

```bash
# Public images (no auth needed)
docker pull ghcr.io/wingadium1/spring-java-thread-performance/spring-mvc-traditional:latest

# Or run directly
docker run -p 8080:8080 ghcr.io/wingadium1/spring-java-thread-performance/spring-mvc-traditional:latest
```

## Need More Details?

📘 **Full Documentation**: [GHCR-AUTHENTICATION.md](GHCR-AUTHENTICATION.md)

## Common Issues

### "insufficient_scope: authorization failed"
**Fix**: Check workflow permissions in repository settings (see "Verifying It Works" above)

### "denied: permission_denied: write_package"  
**Fix**: Ensure "Read and write permissions" is enabled for workflows

### Images not appearing
**Fix**: Check the Actions tab for build errors, ensure the workflow completed successfully

## Summary

**For CI/CD (GitHub Actions)**: ✅ Already configured, works out of the box!

**For Local Development**: Create a PAT with `write:packages` scope and use it to login.

That's it! 🎉
