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

## Test Fixtures

- **baselines/**: Golden reference outputs for regression testing
- **samples_current/**: Symlinks to current test WAV batches
- WAV files should NOT be committed (use symlinks to local files)
- Results written to `tests/results/` (gitignored)

## Notes

- Test fixtures are tracked in git (small JSON/TXT only)
- Large audio files should be symlinked, not committed
- See `tests/fixtures/e2e_speech_script.md` for manual E2E testing guide

