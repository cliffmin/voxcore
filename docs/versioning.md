# Versioning & Release Management

VoxCore uses [Semantic Versioning](https://semver.org/) and automatically tracks version metadata for all recordings. This enables accurate performance analysis by comparing recordings made with specific versions.

## For Users

Version tracking happens automatically. Each recording session includes version metadata:
- VoxCore version (e.g., 0.4.3)
- VoxCompose version (if installed)
- Whisper model used (e.g., base.en)
- Timestamp

## For Developers: Organizing Existing Recordings

If you have existing recordings without version metadata:

### 1. Preview Organization (Dry Run)
```bash
make organize-recordings-dry-run
```

This shows what would be moved without actually moving anything.

### 2. Organize Recordings by Version
```bash
make organize-recordings
```

This will:
- Move recordings to `~/Documents/VoiceNotes/by_version/voxcore-X.Y.Z/`
- Create `.version` files for recordings that don't have them
- Infer version from recording date based on CHANGELOG.md

**Before:**
```
~/Documents/VoiceNotes/
├── 2025-Aug-31_01.04.51_AM/
├── 2025-Sep-17_14.20.00_PM/
└── 2025-Nov-15_09.30.00_AM/
```

**After:**
```
~/Documents/VoiceNotes/by_version/
├── voxcore-0.3.0/
│   └── 2025-Aug-31_01.04.51_AM/
├── voxcore-0.4.0/
│   └── 2025-Sep-17_14.20.00_PM/
└── voxcore-0.4.3/
    └── 2025-Nov-15_09.30.00_AM/
```

### 3. Compare Performance Across Versions
```bash
make compare-versions
```

**Output Example:**
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
    
  v0.4.0:
    Count:  512
    Mean:   450.20ms
    Median: 380.00ms
    
Summary
----------------------------------------
Transcription Speed Improvements:
  Baseline (v0.3.0): 2451ms
  v0.4.0: 450ms (+81.6%, 5.4x faster)
  v0.4.3: 380ms (+84.5%, 6.4x faster)
```

## Semantic Versioning (MAJOR.MINOR.PATCH)

### When to Bump?

**PATCH** (0.4.3 → 0.4.4): Bug fixes only
- Fix crashes or errors
- Performance improvements (no behavior change)
- Documentation updates

**MINOR** (0.4.3 → 0.5.0): New features (backward compatible)
- Add new processor to pipeline
- New configuration options
- New model support
- API additions

**MAJOR** (0.4.3 → 1.0.0): Breaking changes
- Change output format
- Remove/rename config options
- Incompatible changes
- First stable release

## Release Process (For Maintainers)

### 1. Bump Version
```bash
./scripts/utilities/bump_version.sh 0.5.0
```

This updates:
- `whisper-post-processor/build.gradle`
- `whisper-post-processor/src/main/java/com/cliffmin/whisper/WhisperPostProcessorCLI.java`
- `CHANGELOG.md`

### 2. Review & Update CHANGELOG
```bash
git diff
# Manually edit CHANGELOG.md to add release notes
```

### 3. Commit & Tag
```bash
git add -A
git commit -m "chore: bump version to 0.5.0"
git tag -a v0.5.0 -m "Release 0.5.0"
```

### 4. Push
```bash
git push origin main --tags
```

### 5. Create GitHub Release
- Go to https://github.com/cliffmin/voxcore/releases
- Create release from tag `v0.5.0`
- Copy CHANGELOG section as release notes

## VoxCompose Integration

VoxCompose has its own versioning (currently 1.0.0) but is tracked in VoxCore recordings:

```bash
# Check all versions
make version

# Output:
# Git describe: v0.4.3
# Java CLI (whisper-post) version: 0.4.3
# VoxCompose: 1.0.0 (if installed)
```

Both versions are recorded in each session's `.version` file.

## Why This Matters

### Problem
When you improve transcription accuracy or speed, old recordings are still mixed with new ones. This makes performance analysis unreliable:
- "Is this version actually faster?" ❌ Can't tell
- "Did accuracy improve?" ❌ Mixed data
- "When did this bug appear?" ❌ No clear timeline

### Solution
Version-tagged recordings enable:
- **Accurate benchmarks**: Compare apples to apples
- **Regression detection**: Spot when quality drops
- **Progress tracking**: Measure actual improvements
- **Historical analysis**: "What was performance like in v0.3.0?"

## Files Created

### Per Recording Session
```
~/Documents/VoiceNotes/by_version/voxcore-0.4.3/2025-Nov-15_09.30.00_AM/
├── .version                          # Version metadata (auto-created)
├── 2025-Nov-15_09.30.00_AM.wav      # Audio recording
├── 2025-Nov-15_09.30.00_AM.json     # Whisper transcription
└── 2025-Nov-15_09.30.00_AM.txt      # Processed transcript
```

### Transaction Logs
```
~/Documents/VoiceNotes/tx_logs/
├── daily/
│   └── tx-2025-11-15.jsonl          # Daily logs (current format)
└── by_version/                       # Optional: version-separated logs
    ├── voxcore-0.3.0_tx.jsonl
    ├── voxcore-0.4.0_tx.jsonl
    └── voxcore-0.4.3_tx.jsonl
```

## Advanced: Custom Metrics

Compare specific metrics across versions:

```bash
python scripts/analysis/compare_versions.py \
  --versions 0.4.0 0.4.3 0.5.0 \
  --metrics transcription_time duration chars wer
```

Available metrics:
- `transcription_time` - Processing time in ms
- `duration` - Audio duration in seconds
- `chars` - Character count
- `wer` - Word Error Rate (if available from benchmarks)
- `model` - Model used (categorical)

## Troubleshooting

### "No data found for version X.Y.Z"
- Run `make organize-recordings` first
- Check if recordings exist for that version: `ls ~/Documents/VoiceNotes/by_version/`

### ".version file not created"
- Ensure `scripts/utilities/record_version.sh` is executable
- Check Hammerspoon console for errors
- Verify `repoRoot()` returns valid path

### "Version inference wrong"
- Edit `organize_by_version.sh` date thresholds (based on CHANGELOG.md)
- Manually create `.version` files in session directories

## Additional Resources

- **Full Documentation**: [development/versioning.md](development/versioning.md)
- **Script Details**: [../scripts/README.md](../scripts/README.md)
- **Release Process**: [development/release.md](development/release.md)
- **Semantic Versioning**: [semver.org](https://semver.org/)

