# Complete Release Guide: VoxCore + VoxCompose

This guide documents the complete release process for both VoxCore (core application) and VoxCompose (AI plugin), including Homebrew distribution.

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                    End Users                         │
└─────────────────┬───────────────────────────────────┘
                  │
                  ├─── brew install voxcore
                  └─── brew install voxcompose
                  │
┌─────────────────▼───────────────────────────────────┐
│         homebrew-tap (cliffmin/tap)                  │
│  Formula/voxcore.rb    Formula/voxcompose.rb         │
└─────────────────┬───────────────────────────────────┘
                  │
        ┌─────────┴──────────┐
        │                    │
┌───────▼─────────┐   ┌──────▼──────────┐
│   VoxCore       │   │  VoxCompose     │
│   (Core App)    │◄──│  (AI Plugin)    │
│   v0.4.3        │   │  v0.4.4         │
└─────────────────┘   └─────────────────┘
```

**Relationship:**
- **VoxCore** = Core push-to-talk transcription engine (required)
- **VoxCompose** = Optional AI refinement plugin (integrates with VoxCore)
- **Users install VoxCore first, then optionally add VoxCompose**

## Release Process

### VoxCore Release Process

**Prerequisites:**
- All PRs merged to `main`
- CI green (tests passing)
- Local `main` up-to-date

**Steps:**

1. **Update version** (if not already done):
   ```bash
   cd ~/code/voxcore
   # Update version in build.gradle or version files
   # Update CHANGELOG.md
   ```

2. **Commit and push** (if changes needed):
   ```bash
   git add -A
   git commit -m "chore: prepare v0.5.0 release"
   git push origin main
   ```

3. **Create and push tag**:
   ```bash
   NEW_VERSION="0.5.0"
   git tag -a "v${NEW_VERSION}" -m "Release ${NEW_VERSION}: Improved quality with sentence boundary fixes"
   git push origin "v${NEW_VERSION}"
   ```

4. **GitHub Actions automatically**:
   - Builds whisper-post.jar
   - Calculates SHA256 for source tarball
   - Creates GitHub Release
   - Attaches quickstart zip and JAR
   - Includes Homebrew formula SHA256 in release notes

5. **Update Homebrew formula**:
   ```bash
   cd ~/code/homebrew-tap

   # Edit Formula/voxcore.rb:
   # - Update version line: url "https://github.com/cliffmin/voxcore/archive/refs/tags/v0.5.0.tar.gz"
   # - Update sha256 (from GitHub Release notes)

   git add Formula/voxcore.rb
   git commit -m "voxcore: update to v0.5.0"
   git push origin main
   ```

6. **Test the release**:
   ```bash
   brew update
   brew upgrade voxcore
   voxcore-install
   # Test recording
   ```

### VoxCompose Release Process

**Prerequisites:**
- All PRs merged to `main`
- CI green (tests passing)
- Local `main` up-to-date

**Steps:**

1. **Update version in build.gradle.kts**:
   ```bash
   cd ~/code/voxcompose
   # Edit build.gradle.kts
   vim build.gradle.kts  # Change: version = "0.5.0"
   ```

2. **Update CHANGELOG.md**:
   ```markdown
   ## [0.5.0] - 2025-11-27

   ### Added
   - Feature X

   ### Fixed
   - Bug Y
   ```

3. **Commit version bump**:
   ```bash
   git add build.gradle.kts CHANGELOG.md
   git commit -m "chore(release): bump version to 0.5.0"
   git push origin main
   ```

4. **Create and push tag**:
   ```bash
   NEW_VERSION="0.5.0"
   git tag -a "v${NEW_VERSION}" -m "VoxCompose v${NEW_VERSION}"
   git push origin "v${NEW_VERSION}"
   ```

5. **GitHub Actions automatically**:
   - Builds fat JAR: `voxcompose-cli-0.5.0-all.jar`
   - Calculates SHA256
   - Creates GitHub Release
   - Attaches JAR with SHA256 in release notes

6. **Download JAR and get SHA256**:
   ```bash
   cd ~/Downloads
   # Download from GitHub Release
   shasum -a 256 voxcompose-cli-0.5.0-all.jar
   ```

7. **Update Homebrew formula**:
   ```bash
   cd ~/code/homebrew-tap

   # Edit Formula/voxcompose.rb:
   # - Update url: url "https://github.com/cliffmin/voxcompose/releases/download/v0.5.0/voxcompose-cli-0.5.0-all.jar"
   # - Update sha256: sha256 "..." (from previous step)
   # - Update jar filename in install section (line 16, 19)

   git add Formula/voxcompose.rb
   git commit -m "voxcompose: update to v0.5.0"
   git push origin main
   ```

8. **Test the release**:
   ```bash
   brew update
   brew upgrade voxcompose
   echo "pushto github" | voxcompose
   voxcompose --version  # Should show 0.5.0
   ```

## User Upgrade Process

### Upgrading VoxCore

```bash
# Update Homebrew
brew update

# Upgrade VoxCore
brew upgrade voxcore

# Re-run setup (updates Hammerspoon integration)
voxcore-install

# Reload Hammerspoon
# Click menubar → "Reload Config" or press ⌘+⌥+⌃+R

# Test
# Hold ⌘+⌥+⌃+Space to record
```

**What gets updated:**
- Whisper post-processor JAR
- Hammerspoon Lua scripts (symlinked)
- Daemon service (if using `brew services`)

**User config preserved:**
- `~/.hammerspoon/ptt_config.lua` (not overwritten)
- Voice recordings in `~/Documents/VoiceNotes/`

### Upgrading VoxCompose

```bash
# Update Homebrew
brew update

# Upgrade VoxCompose
brew upgrade voxcompose

# Test
echo "test input" | voxcompose
```

**What gets updated:**
- VoxCompose JAR

**User data preserved:**
- `~/.config/voxcompose/learned_profile.json`
- Learning history

### Fresh Installation (New Users)

**Complete setup:**
```bash
# 1. Tap the repository
brew tap cliffmin/tap

# 2. Install Hammerspoon (required for VoxCore)
brew install --cask hammerspoon

# 3. Install VoxCore (core)
brew install voxcore
voxcore-install

# 4. Install VoxCompose (optional AI plugin)
brew install voxcompose ollama
ollama serve &
ollama pull llama3.1

# 5. Configure VoxCore to use VoxCompose
# Edit ~/.hammerspoon/ptt_config.lua
# Set: LLM_REFINER.ENABLED = true

# 6. Reload Hammerspoon
# ⌘+⌥+⌃+R

# 7. Test
# Hold ⌘+⌥+⌃+Space and say "pushto github"
```

## Homebrew Tap Repository

**Location:** `~/code/homebrew-tap`

**GitHub:** `https://github.com/cliffmin/homebrew-tap`

**Formulae:**
- `Formula/voxcore.rb` - VoxCore formula
- `Formula/voxcompose.rb` - VoxCompose formula

**Update checklist after releases:**
1. Update version/URL
2. Update SHA256 checksum
3. Test formula: `brew install --build-from-source cliffmin/tap/[formula]`
4. Commit and push
5. Verify: `brew update && brew info [formula]`

## Current Status (2025-11-27)

### VoxCore
- **Latest Release:** v0.4.3 (Sept 18, 2025)
- **Ready for Release:** v0.5.0 (code done, not tagged)
- **Homebrew Formula:** Points to v0.4.3
- **Action Needed:**
  1. Push 2 commits to main
  2. Create v0.5.0 tag
  3. Update homebrew formula

### VoxCompose
- **Latest Release:** v0.4.4
- **Homebrew Formula:** Points to v0.4.4
- **Status:** ✅ Up to date

## Documentation Links

**VoxCore:**
- Installation: `~/code/voxcore/README.md#quick-start`
- Release Process: `~/code/voxcore/docs/development/release.md`
- Versioning: `~/code/voxcore/docs/development/versioning.md`

**VoxCompose:**
- Installation: `~/code/voxcompose/README.md#quick-start`
- Release Process: `~/code/voxcompose/docs/development/release.md`
- VoxCore Integration: `~/code/voxcompose/docs/voxcore-integration.md`

**Homebrew Tap:**
- README: `~/code/homebrew-tap/README.md`

## Automation & CI/CD

### VoxCore
- **Workflow:** `.github/workflows/release.yml`
- **Triggers:** Tags matching `v*`
- **Artifacts:**
  - `whisper-post.jar`
  - `quickstart-{version}.zip`
  - Homebrew SHA256

### VoxCompose
- **Workflow:** `.github/workflows/release.yml`
- **Triggers:** Tags matching `v*`
- **Artifacts:**
  - `voxcompose-cli-{version}-all.jar`
  - SHA256 checksum

## Best Practices

1. **Always release VoxCore first** if both need updates
   - Users depend on VoxCore as the foundation
   - VoxCompose integration may reference VoxCore versions

2. **Test locally before tagging**:
   ```bash
   # VoxCore
   cd ~/code/voxcore
   make test

   # VoxCompose
   cd ~/code/voxcompose
   ./gradlew test
   ./tests/run_tests.sh
   ```

3. **Update CHANGELOGs** with user-facing changes

4. **Test Homebrew formulas** before pushing:
   ```bash
   brew install --build-from-source cliffmin/tap/voxcore
   ```

5. **Version coordination**:
   - VoxCore and VoxCompose version independently
   - Document integration in release notes if needed

6. **GitHub Release Notes**:
   - Auto-generated from CHANGELOG
   - Include Homebrew SHA256
   - Link to documentation

## Troubleshooting

### "Formula not found"
```bash
brew update
brew tap cliffmin/tap
```

### "SHA256 mismatch"
- Re-download source/JAR
- Recalculate: `shasum -a 256 file`
- Update formula

### "Version not showing after upgrade"
```bash
brew uninstall voxcore voxcompose
brew cleanup
brew install voxcore voxcompose
```

### "Old Hammerspoon scripts after upgrade"
```bash
voxcore-install  # Re-symlinks latest scripts
```

## Quick Reference

**Release VoxCore:**
```bash
cd ~/code/voxcore
git push origin main  # If needed
git tag -a v0.5.0 -m "Release 0.5.0"
git push origin v0.5.0
# Wait for CI, then update homebrew-tap
```

**Release VoxCompose:**
```bash
cd ~/code/voxcompose
# Update build.gradle.kts + CHANGELOG.md
git commit -am "chore(release): bump version to 0.5.0"
git push origin main
git tag -a v0.5.0 -m "VoxCompose v0.5.0"
git push origin v0.5.0
# Wait for CI, download JAR, update homebrew-tap
```

**Update Homebrew Formula:**
```bash
cd ~/code/homebrew-tap
# Edit Formula/*.rb
git commit -am "[project]: update to v0.5.0"
git push origin main
```
