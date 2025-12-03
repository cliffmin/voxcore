# Tests

VoxCore test suite for ensuring quality and preventing regressions.

## Directory Structure

```
tests/
├── fixtures/       # Test data (baselines, golden files, sample WAVs)
├── integration/    # Integration tests (Whisper pipeline, benchmarks)
├── smoke/          # Quick smoke tests (module loading, syntax)
└── util/           # Test utilities (baseline selection, helpers)
```

## Running Tests

### Smoke Tests

Quick validation that modules load without errors:

```bash
# Hammerspoon module load test
bash tests/smoke/push_to_talk_load.sh

# Init.lua syntax check
bash tests/smoke/init_load.sh
```

### Integration Tests

```bash
# Benchmark against a baseline
bash tests/integration/benchmark_against_baseline.sh tests/fixtures/baselines/<baseline_id>
```

### Via Makefile

```bash
make test-smoke       # Run smoke tests
make test-lua         # Run Lua/Hammerspoon tests
```

## Golden Accuracy Tests

Test transcription accuracy against synthetic golden fixtures:

```bash
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

The comparison script exits with code 1 if WER increases by >1% (regression).

## Performance Baseline Tests

Test transcription performance against baseline fixtures:

```bash
# 1. Create baseline fixture (if needed)
python3 tests/util/select_best_fixtures.py

# 2. Establish performance baseline
./scripts/metrics/establish_performance_baseline.sh [BASELINE_DIR]

# 3. Compare current performance against baseline (detects regressions)
./scripts/metrics/compare_performance_baseline.sh [baseline_file]
```

The comparison script exits with code 1 if performance degrades by >20% (regression).

**Note:** Baseline fixtures are stored in `tests/fixtures/baselines/` and contain WAV files organized by duration (short/medium/long).

## Version Filtering

When analyzing real recordings, exclude performance-only versions that aren't suitable for accuracy analysis:

```bash
# Compare versions, excluding performance-only versions
python scripts/analysis/compare_versions.py \
  --versions 0.3.0 0.4.0 0.4.3 0.5.0 \
  --exclude-versions 0.4.1 0.4.2 \
  --metrics transcription_time accuracy
```

Recordings are automatically tagged with version metadata (`.version` file) when created.

## Test Fixtures

- **baselines/**: Golden reference outputs for regression testing
- **golden/**: Synthetic test fixtures with expected transcripts
- **samples_current/**: Symlinks to current test WAV batches
- WAV files should NOT be committed (use symlinks to local files)
- Results written to `tests/results/` (gitignored)

## Plugin Integration Tests

VoxCore tests the plugin contract (how plugins are invoked), not plugin internals:

```bash
# Test plugin contract with mock plugin
bash tests/integration/plugin_contract_test.sh

# Mock plugin verifies:
# - stdin/stdout protocol works
# - Duration metadata passed correctly
# - Arguments handled properly
```

**Note:** Plugin-specific tests (VoxCompose, future plugins) belong in their respective repos. VoxCore only tests the integration contract.

See [PLUGIN_TESTING_STRATEGY.md](../PLUGIN_TESTING_STRATEGY.md) for full details.

## Notes

- Test fixtures are tracked in git (small JSON/TXT only)
- Large audio files should be symlinked, not committed
- See `tests/fixtures/e2e_speech_script.md` for manual E2E testing guide

