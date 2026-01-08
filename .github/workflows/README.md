# GitHub Actions Workflows

## CI Workflow (`ci.yml`)

Runs on every push and pull request to `main`/`master` branches:
- **Shellcheck**: Validates shell script syntax and best practices

## Release Workflow (`release.yml`)

Automatically triggered when a tag matching `v*` is pushed (e.g., `v1.0.0`):
- **Shellcheck**: Validates the script before release
- **Checksum Generation**: Creates SHA256 checksum for integrity verification
- **GitHub Release**: Creates a release with:
  - The script file
  - Checksums file
  - Release notes with installation instructions

### Creating a Release

1. Update version/CHANGELOG if needed
2. Create and push a tag:
   ```bash
   git tag -a v1.0.0 -m "Release v1.0.0"
   git push origin v1.0.0
   ```
3. The workflow will automatically create the GitHub release
