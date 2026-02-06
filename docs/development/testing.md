# Testing

Complete guide for running tests, testing strategy, and plugin testing.

## Quick Start

```bash
make test              # Run all tests
make test-smoke        # Quick smoke tests
make test-java         # Java unit tests
make test-java-all     # Unit + integration tests
```

## Test Suites

### 1. Smoke Tests

Quick validation that modules load without errors.

```bash
make test-smoke
```

Tests Lua syntax validation, module loading, basic configuration. Runs in < 5 seconds.

### 2. Java Unit Tests

Core post-processing logic tests.

```bash
make test-java
# or
cd whisper-post-processor && ./gradlew test
```

Tests the post-processor pipeline, individual processors, edge cases. Runs in ~10-30 seconds.

### 3. Plugin Contract Tests

Verify the plugin integration interface.

```bash
bash tests/integration/plugin_contract_test.sh
```

Tests stdin/stdout protocol, duration metadata passing, capabilities negotiation. Uses a mock plugin (`tests/integration/mock_refiner_plugin.sh`).

### 4. Golden Accuracy Tests

Measure transcription accuracy against known-good fixtures.

```bash
./scripts/metrics/golden_accuracy.sh
./scripts/metrics/compare_golden_accuracy.sh [baseline_file]
```

Measures Word Error Rate (WER) against gold transcripts. Regression threshold: >1% WER increase = failure. Fixtures in `tests/fixtures/golden/` (25 synthetic WAV files).

### 5. Performance Baseline Tests

Detect performance regressions.

```bash
./scripts/metrics/establish_performance_baseline.sh
./scripts/metrics/compare_performance_baseline.sh [baseline_file]
```

Regression threshold: >20% slower = failure.

## Testing Strategy

### Philosophy

- **Baselines, not perfection** -- tests establish baseline metrics, not 100% pass rates
- **Accuracy + speed** -- track both transcription accuracy and processing time
- **Regression prevention** -- CI ensures performance doesn't drop below thresholds
- **Feature-specific** -- each feature has dedicated golden datasets

### Golden Dataset Structure

```
tests/fixtures/golden/
  micro/          # Edge cases (single word)
  short/          # Short clips (5-10 seconds)
  medium/         # Medium clips (10-21 seconds)
  long/           # Long clips (>21 seconds)
  challenging/    # Word separation tests
  natural/        # Filler word tests
```

Each fixture includes: `{name}.wav`, `{name}.txt` (expected), `{name}.raw.txt` (whisper output), `{name}.json` (metadata).

## Plugin Testing

**Core principle: Plugin tests belong in the plugin repo. Integration tests belong in VoxCore.**

| Test Type | Location | Reason |
|-----------|----------|--------|
| Plugin unit tests | Plugin repo | Plugin owns its logic |
| Plugin CLI tests | Plugin repo | Plugin tests its interface |
| **Plugin contract** | **VoxCore repo** | **VoxCore owns the contract** |
| Full-stack E2E | VoxCore (manual) | Validates real integration |

VoxCore tests the contract with a mock plugin. Plugins (like VoxCompose) test themselves independently with no VoxCore dependency. This scales to any number of plugins.

## CI/CD

### On Every PR

- Java unit tests
- Validation (Lua syntax, shellcheck, plugin contract, docs check)

### On Main Branch Push

- All PR checks + upgrade tests

### Weekly

- Performance benchmark regression tests

## Development Workflow

### Before Committing

```bash
make test-smoke
make test-java
```

### Before Releasing

```bash
make test-smoke
make test-java
./scripts/metrics/golden_accuracy.sh
./scripts/metrics/compare_performance_baseline.sh baseline_file.json
```

## Troubleshooting

- **Tests fail locally but pass in CI**: Check Java version (CI uses Java 17), dependencies (`brew bundle`), environment variables
- **Plugin contract test fails**: Ensure mock plugin is executable (`chmod +x tests/integration/mock_refiner_plugin.sh`), `jq` installed
- **Golden accuracy test fails**: Verify fixtures exist, raw outputs generated, post-processor JAR built

## Related

- [Architecture](architecture.md)
- [Versioning](versioning.md)
- [Local Testing](local-testing.md)
