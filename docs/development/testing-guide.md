# Testing Guide

Complete guide for running tests and the local development workflow.

## Quick Start

```bash
# Run all tests
make test

# Run specific test suites
make test-smoke          # Quick smoke tests
make test-java          # Java unit tests
bash tests/integration/plugin_contract_test.sh  # Plugin contract
```

## Test Suites

### 1. Smoke Tests

**Purpose:** Quick validation that modules load without errors

```bash
# Run all smoke tests
make test-smoke

# Individual tests
bash tests/smoke/push_to_talk_load.sh  # Hammerspoon module
bash tests/smoke/init_load.sh          # Init.lua syntax
```

**What they test:**
- Lua syntax validation
- Module loading
- Basic configuration

**Time:** < 5 seconds

### 2. Java Unit Tests

**Purpose:** Test core post-processing logic

```bash
# Run all Java tests
make test-java
# or
cd whisper-post-processor && ./gradlew test

# Run specific test class
cd whisper-post-processor && ./gradlew test --tests "com.cliffmin.whisper.processors.MergedWordProcessorTest"
```

**What they test:**
- Post-processor pipeline
- Individual processors
- Edge cases and error handling

**Time:** ~10-30 seconds

### 3. Plugin Contract Tests

**Purpose:** Verify plugin integration interface works correctly

```bash
# Run plugin contract tests
bash tests/integration/plugin_contract_test.sh
```

**What they test:**
- stdin/stdout protocol
- Duration metadata passing
- Capabilities negotiation
- Edge cases (empty input, multi-line)

**Time:** < 1 second

**Mock plugin:** `tests/integration/mock_refiner_plugin.sh`

### 4. Golden Accuracy Tests

**Purpose:** Measure transcription accuracy against known-good fixtures

```bash
# Full workflow
# 1. Generate golden test data (if needed)
./scripts/utilities/generate_test_data.sh

# 2. Capture raw whisper output
./scripts/utilities/rebaseline_golden.sh

# 3. Process with post-processor
./scripts/utilities/process_golden_with_post.sh

# 4. Run accuracy benchmark
./scripts/metrics/golden_accuracy.sh

# 5. Compare against baseline (detects regressions)
./scripts/metrics/compare_golden_accuracy.sh [baseline_file]
```

**What they test:**
- Word Error Rate (WER) against gold transcripts
- Post-processor improvements
- Regression detection (>1% WER increase = failure)

**Time:** ~2-5 minutes (depends on number of fixtures)

**Fixtures:** `tests/fixtures/golden/` (25 synthetic WAV files)

### 5. Performance Baseline Tests

**Purpose:** Detect performance regressions

```bash
# 1. Create baseline fixture (if needed)
python3 tests/util/select_best_fixtures.py

# 2. Establish performance baseline
./scripts/metrics/establish_performance_baseline.sh [BASELINE_DIR]

# 3. Compare current performance against baseline
./scripts/metrics/compare_performance_baseline.sh [baseline_file]
```

**What they test:**
- Transcription speed (ms)
- Processing overhead
- Regression detection (>20% slower = failure)

**Time:** ~1-3 minutes

**Baselines:** `tests/fixtures/baselines/`

### 6. Version Comparison Tests

**Purpose:** Compare performance across VoxCore versions

```bash
# Compare versions (excludes VoxCompose recordings by default)
python scripts/analysis/compare_versions.py \
  --versions 0.4.3 0.5.0 \
  --metrics transcription_time accuracy

# Include VoxCompose recordings
python scripts/analysis/compare_versions.py \
  --versions 0.4.3 0.5.0 \
  --include-voxcompose

# Filter by specific VoxCompose version
python scripts/analysis/compare_versions.py \
  --versions 0.4.3 0.5.0 \
  --voxcompose-version 1.0.0
```

**What they test:**
- Performance improvements across versions
- Accuracy changes
- Version-specific metrics

**Time:** Depends on number of recordings

**Data:** `~/Documents/VoiceNotes/by_version/`

## Local Development Workflow

### Daily Development

```bash
# 1. Make changes to code
vim hammerspoon/push_to_talk.lua
# or
vim whisper-post-processor/src/main/java/...

# 2. Run quick smoke test
make test-smoke

# 3. Test locally (if changing transcription)
# Record a test clip
# Hold Cmd+Alt+Ctrl+Space, speak, release
# Check output in target app

# 4. Run relevant unit tests
make test-java  # If changing Java code
bash tests/integration/plugin_contract_test.sh  # If changing plugin interface

# 5. Commit when ready
git add .
git commit -m "ptt: your change description"
```

### Before Committing

```bash
# Run all fast tests
make test-smoke
make test-java
bash tests/integration/plugin_contract_test.sh

# Check for linting issues
shellcheck scripts/**/*.sh
```

### Before Pushing PR

```bash
# Full test suite (what CI will run)
make test-smoke
make test-java
bash tests/integration/plugin_contract_test.sh

# Optional: Run golden accuracy (if changing post-processing)
./scripts/metrics/golden_accuracy.sh
./scripts/metrics/compare_golden_accuracy.sh
```

### Before Releasing

```bash
# 1. Run all tests
make test-smoke
make test-java
bash tests/integration/plugin_contract_test.sh

# 2. Verify golden accuracy (no regressions)
./scripts/metrics/golden_accuracy.sh
./scripts/metrics/compare_golden_accuracy.sh baseline_file.json

# 3. Check performance baseline (no regressions)
./scripts/metrics/compare_performance_baseline.sh baseline_file.json

# 4. Test install workflow (manual)
# Trigger install-test.yml workflow in GitHub Actions

# 5. Test upgrade workflow (manual, after merge)
# Trigger install-test.yml workflow with upgrade mode
```

## CI/CD Test Execution

### On Every PR

**Automatically runs:**
1. ✅ Java unit tests (`java-tests` job)
2. ✅ Validation (`validation` job):
   - Lua syntax check
   - Shellcheck
   - Plugin contract test
   - Documentation check

**Manual trigger:**
- Install test (`install-upgrade-test.yml` workflow)

### On Main Branch Push

**Automatically runs:**
1. ✅ All PR checks
2. ✅ Upgrade test (`upgrade-test` job in `install-upgrade-test.yml`)

**Manual trigger:**
- Full-stack test (VoxCore + VoxCompose)

## Test Data

### Golden Fixtures

**Location:** `tests/fixtures/golden/`

**Categories:**
- `micro/` - Edge cases (single word, two words)
- `short/` - Short clips (5-10 seconds)
- `medium/` - Medium clips (10-21 seconds)
- `long/` - Long clips (>21 seconds)
- `challenging/` - Word separation tests
- `natural/` - Filler word tests
- `real/` - Real recordings (gitignored, local only)

**Files per fixture:**
- `{name}.wav` - Audio file
- `{name}.txt` - Gold transcript (expected output)
- `{name}.raw.txt` - Raw whisper output (created by rebaseline)
- `{name}.processed.txt` - Post-processed output (created during testing)
- `{name}.json` - Metadata

### Performance Baselines

**Location:** `tests/fixtures/baselines/`

**Structure:**
```
baselines/
└── baseline_YYYYMMDD-HHMM/
    ├── short/
    │   ├── sample1.wav
    │   └── sample1.json
    ├── medium/
    └── long/
```

**Created by:** `tests/util/select_best_fixtures.py`

## Troubleshooting

### Tests Fail Locally But Pass in CI

**Check:**
- Java version (CI uses Java 17)
- Dependencies installed (`brew bundle`)
- Environment variables

### Plugin Contract Test Fails

**Check:**
- Mock plugin is executable: `chmod +x tests/integration/mock_refiner_plugin.sh`
- `jq` installed: `brew install jq`
- Script paths are correct

### Golden Accuracy Test Fails

**Check:**
- Golden fixtures exist: `ls tests/fixtures/golden/*/*.wav`
- Raw outputs generated: `ls tests/fixtures/golden/*/*.raw.txt`
- Post-processor JAR built: `ls whisper-post-processor/dist/whisper-post.jar`

### Performance Baseline Test Fails

**Check:**
- Baseline exists: `ls tests/fixtures/baselines/`
- Baseline JSON valid: `jq . tests/fixtures/baselines/*/baseline.json`
- Current benchmark run: `ls tests/results/performance_baseline_*.json`

## Best Practices

1. **Run smoke tests frequently** - Fast feedback during development
2. **Run unit tests before committing** - Catch issues early
3. **Run golden accuracy before releases** - Ensure no regressions
4. **Keep baselines updated** - Re-baseline after significant changes
5. **Test with real recordings** - Use your actual voice notes for validation

## Related Documentation

- [Plugin Testing Strategy](../PLUGIN_TESTING_STRATEGY.md)
- [CI/CD Review](../CI_CD_REVIEW.md)
- [Versioning Guide](versioning.md)
- [Architecture](architecture.md)

