# Release Process

This document defines the formal process to cut a VoxCore release and update a local system.

## Versioning
- Use semver-like tags: vMAJOR.MINOR.PATCH (e.g., v0.4.1)
- Patch: bug fixes / non-breaking changes
- Minor: new features (backward compatible)
- Major: breaking changes (requires migration notes)

## Automated Releases (preferred)

Trigger: push a tag matching v*.*.* to origin

1) Ensure main is green
   - CI must pass on main before tagging

2) Tag and push
```bash
git checkout main
git pull
git tag -a v0.4.1 -m "VoxCore v0.4.1"
git push origin v0.4.1
```

3) CI builds and publishes a GitHub Release automatically
   - Artifacts:
     - macos-ptt-dictation-release.tar.gz (bundle)
     - whisper-post-processor/dist/whisper-post.jar

4) Add release notes (optional but recommended)
   - Edit the GitHub Release to include highlights, changes, and migration notes

## Manual Release (fallback)

1) Merge PR to main and wait for CI
2) Download the release-bundle artifact from the Release job
3) Create a GitHub Release manually and attach artifacts

## Local Update (developer machine)

Option A: Update from source
```bash
# from repo root
git checkout main
git pull
make build-java
./scripts/setup/install.sh
# Reload Hammerspoon
```

Option B: Update from GitHub Release
```bash
# Download release tarball from GitHub Releases
tar -xzf macos-ptt-dictation-release.tar.gz
cd release
./scripts/setup/install.sh
# Reload Hammerspoon
```

## Additional Notes
- Homebrew formula (dist/HomebrewFormula) remains macos-ptt-dictation until repo rename; will migrate to voxcore formula later
- Ensure README and WARP.md remain accurate after user-visible changes
- Add CHANGELOG and migration notes for behavior changes
