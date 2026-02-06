# Versioning & Release Management

## Semantic Versioning

VoxCore follows [Semantic Versioning 2.0.0](https://semver.org/): `MAJOR.MINOR.PATCH`

### When to Increment

**PATCH** (0.4.3 → 0.4.4): Backward-compatible bug fixes
- Fix transcription errors or crashes
- Performance improvements (no behavior change)
- Documentation updates
- Dependency security patches

**MINOR** (0.4.3 → 0.5.0): Backward-compatible new features
- Add new processor to pipeline
- New configuration options (with defaults)
- New model support
- API additions (non-breaking)
- New integrations

**MAJOR** (0.4.3 → 1.0.0): Breaking changes
- Change transcription output format
- Remove or rename configuration options
- Change API contracts
- Incompatible architecture changes
- Graduate to 1.0 (production-ready)

### Pre-1.0 Behavior (Current: 0.x.x)

- Breaking changes may occur in MINOR versions
- PATCH versions are always safe to upgrade
- Target 1.0.0 when core API is stable

## Recording Organization by Version

### Why Version Recordings?

Performance analysis requires comparing recordings made with the same code/models. When you improve accuracy or speed, you need to separate old data from new data to measure progress accurately.

### Directory Structure

```
~/Documents/VoiceNotes/
├── by_version/
│   ├── voxcore-0.3.0/          # All recordings made with v0.3.0
│   ├── voxcore-0.4.0/          # All recordings made with v0.4.0
│   ├── voxcore-0.4.3/          # All recordings made with v0.4.3
│   └── voxcore-0.5.0/          # Future version
├── tx_logs/
│   ├── by_version/
│   │   ├── voxcore-0.3.0_tx.jsonl
│   │   ├── voxcore-0.4.0_tx.jsonl
│   │   └── voxcore-0.4.3_tx.jsonl
│   └── daily/
│       └── tx-YYYY-MM-DD.jsonl
└── benchmarks/
    ├── voxcore-0.3.0-baseline.json
    └── voxcore-0.4.3-baseline.json
```

### Version Metadata

Each recording session contains a `.version` file:

```
voxcore=0.4.3
voxcompose=1.0.0
model=base.en
timestamp=2025-11-15T19:30:00Z
```

This file is automatically created when recordings are made.

## Retroactive Organization

If you have existing recordings without version metadata:

```bash
# Dry run first to preview changes
./scripts/utilities/organize_by_version.sh --dry-run

# Actually organize recordings
./scripts/utilities/organize_by_version.sh
```

This script:
1. Infers version from recording date (based on CHANGELOG.md)
2. Creates `.version` files for untagged recordings
3. Moves recordings to `by_version/voxcore-X.Y.Z/` directories
4. Preserves all files (WAV, JSON, TXT)

## Going Forward

### Automatic Version Recording

Version metadata is automatically recorded for new sessions. The `record_version.sh` script is called by `push_to_talk_v2.lua` after each recording.

No action needed - it just works!

### Release Process

1. **Update version number:**
   ```bash
   ./scripts/utilities/bump_version.sh 0.5.0
   ```

2. **Review changes:**
   ```bash
   git diff
   ```

3. **Update CHANGELOG.md:**
   Add release notes under `[0.5.0] - 2025-11-15` section

4. **Commit and tag:**
   ```bash
   git add -A
   git commit -m "chore: bump version to 0.5.0"
   git tag -a v0.5.0 -m "Release 0.5.0"
   ```

5. **Push:**
   ```bash
   git push origin main --tags
   ```

6. **Optional: Create GitHub Release**
   - Go to GitHub Releases
   - Create release from tag v0.5.0
   - Copy CHANGELOG section as release notes

## Performance Analysis

Compare versions using the analysis script:

```bash
# Compare default versions (0.3.0, 0.4.0, 0.4.3)
python scripts/analysis/compare_versions.py

# Compare specific versions
python scripts/analysis/compare_versions.py --versions 0.4.0 0.4.3

# Focus on specific metrics
python scripts/analysis/compare_versions.py --metrics transcription_time accuracy

# Exclude performance-only versions (not suitable for accuracy analysis)
python scripts/analysis/compare_versions.py \
  --versions 0.3.0 0.4.0 0.4.3 0.5.0 \
  --exclude-versions 0.4.1 0.4.2 \
  --metrics transcription_time accuracy

# Include VoxCompose recordings (default: excluded for clean VoxCore metrics)
python scripts/analysis/compare_versions.py --include-voxcompose

# Only include specific VoxCompose version
python scripts/analysis/compare_versions.py --voxcompose-version 1.0.0
```

**Note**: 
- Some versions may include performance enhancements that make recordings unsuitable for accuracy analysis. Use `--exclude-versions` to filter these out.
- By default, recordings made with VoxCompose are excluded to measure VoxCore performance in isolation. Use `--include-voxcompose` to include them, or `--voxcompose-version X.Y.Z` to filter by specific VoxCompose version.

Output example:
```
VoxCore Version Comparison
================================================================================

v0.3.0: 245 recordings
v0.4.0: 512 recordings
v0.4.3: 402 recordings

--------------------------------------------------------------------------------

Metric: transcription_time
----------------------------------------
  v0.3.0:
    Count:  245
    Mean:   2450.50ms
    Median: 2100.00ms
    Range:  800.00 - 8500.00ms
    
  v0.4.0:
    Count:  512
    Mean:   450.20ms    # 5.4x faster!
    Median: 380.00ms
    Range:  150.00 - 1800.00ms
```

## VoxCompose Integration

VoxCompose has its own versioning but is tracked in VoxCore recordings:

```bash
# Check versions
make version

# Output:
# Git describe: v0.4.3
# Java CLI (whisper-post) version: 0.4.3 (from build.gradle)
# VoxCompose: 1.0.0 (if installed)
```

Both versions are recorded in `.version` files for full traceability.

## Best Practices

1. **Before releasing:** Run benchmarks on golden fixtures
2. **After releasing:** Keep recordings from that version for future comparison
3. **Document breaking changes:** Clearly mark in CHANGELOG.md
4. **Tag early, tag often:** Even pre-releases (v0.5.0-beta.1)
5. **Keep at least 3 versions:** Current, previous, baseline (for comparison)

## Related Files

- `scripts/utilities/bump_version.sh` - Bump version across all files
- `scripts/utilities/record_version.sh` - Record version metadata (auto-called)
- `scripts/utilities/organize_by_version.sh` - Retroactively organize recordings
- `scripts/analysis/compare_versions.py` - Compare performance across versions
- `CHANGELOG.md` - User-facing changelog

