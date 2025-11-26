# Scripts

Utility scripts for VoxCore development, testing, analysis, and operations.

## Directory Structure

### `analysis/`
Performance analysis and log processing scripts.

- `analyze_durations.py` - Parse and analyze transcription durations
- `analyze_logs.py` - Parse and analyze transcription logs
- `analyze_performance.sh` - Comprehensive performance analysis with recommendations
- `compare_benchmarks.py` - Compare benchmark results across runs
- `compare_versions.py` - **Compare performance metrics across VoxCore versions** ⭐

### `ci/`
Continuous integration scripts.

- `prepush.sh` - Pre-push validation (linting, tests)

### `diagnostics/`
Diagnostic and troubleshooting utilities.

- `collect_latest.sh` - Collect recent logs and generate diagnostic summary
- `summarize_tx.py` - Summarize transaction logs

### `metrics/`
Performance metrics and benchmarking.

- `render_metrics.py` - Generate performance graphs from transaction logs
- `sweep_threshold.py` - Find optimal model-switching threshold

### `setup/`
Installation and configuration scripts.

- `install.sh` - Main installation script
- `auto_select_audio_device.sh` - Automatically detect and configure best audio device
- `uninstall.sh` - Uninstall VoxCore

### `testing/`
Testing utilities and test scripts.

- `daemon_health.sh` - Check Java daemon health
- `debug_recording.sh` - Debug audio recording issues
- `test_f13_modes.sh` - Test F13 keybinding modes

### `utilities/`
General-purpose utilities for development and operations.

- `bump_version.sh` - Bump version across all project files (semver)
- `generate_test_data.sh` - Generate synthetic test data
- `query_refiner_capabilities.lua` - Query refiner (VoxCompose) capabilities
- `record_version.sh` - **Record version metadata for recording sessions** ⭐ (auto-called)
- `organize_by_version.sh` - **Organize recordings by version retroactively** ⭐

## Versioning & Recording Organization

### New in v0.4.3+

Scripts for organizing recordings by software version to enable accurate performance analysis:

#### `utilities/record_version.sh`
Automatically records version metadata for each recording session.

**Usage:** Called automatically by `push_to_talk.lua` after transcription.

Creates a `.version` file in each session directory:
```
voxcore=0.4.3
voxcompose=1.0.0
model=base.en
timestamp=2025-11-15T19:30:00Z
```

#### `utilities/organize_by_version.sh`
Retroactively organizes existing recordings by version.

**Usage:**
```bash
# Dry run first (preview changes)
./scripts/utilities/organize_by_version.sh --dry-run

# Actually organize
./scripts/utilities/organize_by_version.sh
```

**What it does:**
- Infers version from recording date (based on CHANGELOG.md)
- Creates `.version` files for untagged recordings
- Moves recordings to `~/Documents/VoiceNotes/by_version/voxcore-X.Y.Z/`

#### `analysis/compare_versions.py`
Compares performance metrics across versions.

**Usage:**
```bash
# Compare default versions (0.3.0, 0.4.0, 0.4.3)
python scripts/analysis/compare_versions.py

# Compare specific versions
python scripts/analysis/compare_versions.py --versions 0.4.0 0.4.3 0.5.0

# Focus on specific metrics
python scripts/analysis/compare_versions.py --metrics transcription_time accuracy wer
```

**Output:**
```
VoxCore Version Comparison
================================================================================

v0.3.0: 245 recordings
v0.4.0: 512 recordings
v0.4.3: 402 recordings

Metric: transcription_time
  v0.3.0: Mean: 2450.50ms
  v0.4.0: Mean: 450.20ms (81.6% improvement, 5.4x faster)
  v0.4.3: Mean: 380.00ms (84.5% improvement, 6.4x faster)
```

### Makefile Targets

Quick access via `make`:

```bash
make organize-recordings          # Organize recordings by version
make organize-recordings-dry-run  # Preview organization
make compare-versions             # Compare performance across versions
```

## Quick Start

### First-Time Setup
```bash
# Install VoxCore
./scripts/setup/install.sh

# Auto-configure audio device
make auto-audio
```

### Performance Analysis
```bash
# Collect recent logs
./scripts/diagnostics/collect_latest.sh

# Analyze performance
./scripts/analysis/analyze_performance.sh

# Compare versions
make compare-versions
```

### Version Management
```bash
# Check current version
make version

# Bump version (for maintainers)
./scripts/utilities/bump_version.sh 0.5.0

# Organize recordings by version
make organize-recordings
```

### Testing
```bash
# Run all tests
make test

# Run smoke tests
make test-smoke

# Test Java components
make test-java
```

### Diagnostics
```bash
# Check daemon health
./scripts/testing/daemon_health.sh

# Debug recording issues
./scripts/testing/debug_recording.sh

# Collect diagnostic summary
./scripts/diagnostics/collect_latest.sh
```

## Development Workflow

### Before Committing
```bash
# Run pre-push checks
./scripts/ci/prepush.sh
```

### Releasing a New Version
```bash
# 1. Bump version
./scripts/utilities/bump_version.sh 0.5.0

# 2. Review changes
git diff

# 3. Update CHANGELOG.md manually

# 4. Commit and tag
git add -A
git commit -m "chore: bump version to 0.5.0"
git tag -a v0.5.0 -m "Release 0.5.0"

# 5. Push
git push origin main --tags
```

See `docs/development/versioning.md` for detailed versioning guidelines.

## Contributing

When adding new scripts:
1. Place in the appropriate directory
2. Add execution permissions: `chmod +x script.sh`
3. Update this README with description
4. Add usage examples
5. Consider adding Makefile target for common use

## See Also

- `docs/development/testing.md` - Testing guidelines
- `docs/development/release.md` - Release process
- `docs/development/versioning.md` - Versioning best practices
