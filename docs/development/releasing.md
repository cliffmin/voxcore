# Releasing VoxCore

How to create and publish a new release.

## Version Numbering

VoxCore follows [Semantic Versioning](https://semver.org/):
- **MAJOR** (1.0.0): Breaking changes, API incompatibility
- **MINOR** (0.5.0): New features, backward compatible
- **PATCH** (0.4.1): Bug fixes, backward compatible

## Pre-Release Checklist

- [ ] All tests pass: `make test`
- [ ] CHANGELOG.md updated with new version section
- [ ] Version bumped in `whisper-post-processor/build.gradle` (if applicable)
- [ ] PR merged to main

## Release Steps

### 1. Ensure main is up to date

```bash
git checkout main
git pull origin main
```

### 2. Create and push tag

```bash
# Create annotated tag
git tag -a v0.5.0 -m "Release v0.5.0: Sentence boundary fixes"

# Push tag
git push origin v0.5.0
```

### 3. Create GitHub Release (optional)

```bash
gh release create v0.5.0 \
  --title "v0.5.0" \
  --notes "See CHANGELOG.md for details"
```

Or create manually at: https://github.com/cliffmin/voxcore/releases/new

### 4. Update Homebrew Formula

```bash
# Get sha256 of new tarball
curl -sL https://github.com/cliffmin/voxcore/archive/refs/tags/v0.5.0.tar.gz | shasum -a 256

# Update homebrew-tap
cd ~/code/homebrew-tap
```

Edit `Formula/voxcore.rb`:
```ruby
url "https://github.com/cliffmin/voxcore/archive/refs/tags/v0.5.0.tar.gz"
sha256 "<new-sha256-here>"
```

```bash
git add Formula/voxcore.rb
git commit -m "voxcore: update to v0.5.0"
git push
```

### 5. Verify Installation

```bash
brew update
brew upgrade voxcore

# Test
whisper-post --version
voxcore-install  # Re-run to update symlinks if needed
```

## User Upgrade Path

For most releases, users simply run:
```bash
brew update && brew upgrade voxcore
```

If the release includes breaking changes, document migration steps in CHANGELOG.md under a "Migration" or "Breaking Changes" section.

## When to Write an Upgrade Guide

**Not needed for:**
- Bug fixes
- New features with no config changes
- Performance improvements

**Needed for:**
- Config file format changes
- Renamed/removed settings
- New required dependencies
- Data migration required

## Hotfix Process

For urgent fixes to a released version:

```bash
# Create hotfix branch from tag
git checkout -b hotfix/0.5.1 v0.5.0

# Make fixes, then:
git tag -a v0.5.1 -m "Hotfix: <description>"
git push origin v0.5.1

# Merge back to main
git checkout main
git merge hotfix/0.5.1
git push origin main
```

## Release Automation (Future)

Consider adding GitHub Actions workflow:
- Auto-create release on tag push
- Auto-update homebrew formula
- Run release tests

See `.github/workflows/` for existing CI setup.
