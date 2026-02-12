# Test Evaluation (All Repos)

Evaluation of test suites across voxcore, voxcompose, and homebrew-tap for project size, complexity, intent, overlap, brittleness, and unnecessary tests. Last updated: 2026-02.

---

## VoxCore

### Scope

- **Intent**: Local push-to-talk transcription; CLI + post-processors; optional daemon (deprecated).
- **Size**: ~23 test classes; unit (no integration tag) + integration (tagged); benchmark workflow in CI.
- **Complexity**: Medium – 10 processors, config, CLI, daemon legacy.

### What’s Valuable

| Area | Tests | Verdict |
|------|--------|--------|
| **Processor regression** | `RegressionTest`, per-processor unit tests | Keep. Core quality signal; fast. |
| **Accuracy (text pipeline)** | `AccuracyTest` (golden-dataset.json, 29 cases) | Keep. Single source of truth for pipeline accuracy. |
| **Config** | `PathExpanderTest`, `DirectoryValidatorTest`, `VocabularyLoadingTest`, etc. | Keep. Config is critical and well-scoped. |
| **CLI** | `WhisperPostProcessorCLITest` | Keep. |
| **Benchmark regression** | `benchmark_cli.sh` + CI workflow, golden-public WAVs | Keep. Prevents performance/accuracy regressions. |

### Overlap / Redundancy

1. **Two “accuracy” concepts**
   - **`AccuracyTest.java`** (package `com.cliffmin.whisper`): Uses `golden-dataset.json` (29 text-only cases). Runs in `integrationTest`. **Primary** pipeline-accuracy test.
   - **`FullTestSuite` inner `AccuracyTest`**: Uses `tests/fixtures/golden/` (WAVs). Skips if dir missing. **Legacy**; depends on personal golden data.
   - **Recommendation**: Treat `AccuracyTest.java` + `golden-dataset.json` as the standard. Document in `FullTestSuite` that the inner accuracy test is optional/local (golden/ not in repo). No need to delete unless we want to simplify the suite.

2. **RegressionTest vs AccuracyTest**
   - Regression: many small, targeted assertions (sentence boundaries, merged words, etc.).
   - Accuracy: full pipeline over 29 golden text cases.
   - **No real overlap** – one is unit-level behavior, the other end-to-end text accuracy. Both stay.

### Brittle / Legacy

| Item | Issue | Recommendation |
|------|--------|----------------|
| **FullTestSuite** | References `tests/fixtures/golden` and hardcoded `~/.local/bin/whisper`. | Add a short comment that it’s for local/manual runs when golden WAVs exist. Optional: make paths configurable via system props. |
| **PTTServiceDaemonTest / PTTServiceDaemonWiredConfigTest** | Test deprecated daemon. | Keep while daemon code exists (used by formula/caveats). If daemon is removed from the repo, remove these tests. |
| **ContextProcessorTest** | Tests `ContextProcessor` (still in codebase but not in default CLI pipeline). | Keep; class still exists. If we delete the class, delete the test. |
| **E2EIntegrationTest** | Spawns Gradle; depends on env. | Keep; already integration-only. Accept some brittleness for E2E. |

### Unnecessary for This Project

- **No tests to remove by name.** Daemon and context tests are still testing live code. FullTestSuite’s inner accuracy test is redundant in *purpose* with `AccuracyTest` but runs only when golden/ exists; low cost.
- **Fixture size limit (10 MB)** is appropriate; keeps CI and clone size under control.

### CI Workflows (VoxCore)

| Workflow | Role | Verdict |
|----------|------|--------|
| ci.yml | Unit tests, validation, fixture size, large-files check | Keep; necessary. |
| benchmark-regression.yml | End-to-end benchmark on golden-public | Keep; threshold 38% for CI without vocab. |
| install-test.yml, install-upgrade-test.yml | Brew install/upgrade | Keep for release quality. |
| codeql.yml | Security | Keep. |
| release.yml, update-formula.yml | Release / formula | Keep. |

**Summary (VoxCore):** No unnecessary tests for project size. Minor overlap (two accuracy mechanisms) is documented and acceptable. One brittle area (FullTestSuite paths); document only unless we refactor.

---

## VoxCompose

### Scope

- **Intent**: Optional refinement plugin (learning, corrections, vocabulary export); CLI.
- **Size**: 4 JUnit test classes; 6+ shell scripts in `tests/`.
- **Complexity**: Low–medium.

### What’s Valuable

| Area | Tests | Verdict |
|------|--------|--------|
| **Config** | `ConfigurationTest` | Keep. |
| **Learning / profile** | `LearningServiceTest`, `UserProfileTest` | Keep. |
| **Vocabulary export** | `VocabularyExportIntegrationTest` | Keep (integration with VoxCore). |
| **Shell scripts** | `test_capabilities.sh`, `test_corrections.sh`, `test_duration_threshold.sh`, `validate_self_learning.sh`, etc. | Keep for local/manual; require Ollama/LLM. |

### Overlap / Brittleness

- **No meaningful overlap** between JUnit tests.
- **Shell tests**: Not run in CI (need Ollama). Brittle only if they assume specific Ollama models or outputs; acceptable for optional integration tests.
- **CI** runs only `./gradlew test` (unit). Appropriate; no need to run LLM-dependent scripts in every PR.

### Unnecessary for This Project

- None. Test count and scope match project size and intent.

**Summary (VoxCompose):** Test suite is proportionate. No removals recommended.

---

## Homebrew Tap

### Scope

- **Intent**: Distribute voxcore and voxcompose formulae.
- **Size**: One CI workflow (formula audit).

### What’s There

- **ci.yml**: `brew tap` from workspace; `brew audit --strict` for both formulae; optional `brew style`.
- No test code in repo; formulae are the artifact.

### Verdict

- **Appropriate.** Single audit job is enough for tap size. No extra tests needed.

---

## Cross-Repo

- **VoxCore** is tested in isolation (unit + integration + benchmark). No dependency on voxcompose in tests.
- **VoxCompose** has its own unit tests and optional integration (vocabulary export). No duplicate testing of VoxCore.
- **Tap** only validates formula syntax/style.

**Conclusion:** For current project size, complexity, and intent, test suites are in good shape. No unnecessary tests identified; only minor overlap (documented) and one brittle path (FullTestSuite) to optionally tidy later.
