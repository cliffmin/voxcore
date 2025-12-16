# Test Fixtures Manifest

## Overview

This directory contains test fixtures for VoxCore transcription testing. This manifest documents essential fixtures, their purpose, and ownership.

**Current State:**
- Total committed WAV files: 64 (32 golden + 32 golden-features)
- Total fixture size: ~9MB
- Hard limit: 10MB (enforced by CI)

## Philosophy

1. **Prefer synthetic generation** - Use `say` + `ffmpeg` to generate test audio on-the-fly
2. **Minimal committed fixtures** - Only commit fixtures that cannot be synthetically generated
3. **Clear ownership** - Every fixture must be referenced by at least one test
4. **Size discipline** - CI enforces 10MB hard limit on committed fixtures

## Directory Structure

```
tests/fixtures/
├── golden/              # Core accuracy test fixtures (ESSENTIAL)
│   ├── micro/          # Edge cases: single words, minimal audio
│   ├── short/          # 5-15s clips: accents, numbers, punctuation
│   ├── medium/         # 20-30s clips: mixed technical content
│   ├── long/           # 45-75s clips: full paragraphs
│   ├── challenging/    # Known-hard cases: fast speech, accents
│   ├── natural/        # Real-world: disfluencies, pauses
│   └── real/           # Actual VoxCore usage examples
├── golden-features/     # Feature-specific test fixtures (REVIEW)
│   ├── baseline/       # Baseline comparison
│   ├── filler-words/   # Disfluency removal tests
│   ├── vocabulary/     # Custom vocab tests
│   └── word-separation/# Reflow and gap detection
├── baselines/          # Timestamped regression baselines (LOCAL ONLY - .gitignored)
└── e2e_speech_script.md # Manual E2E test script (KEEP)
```

## Essential Fixtures (Keep)

### golden/micro/ (2 fixtures)
- `edge_single_word.wav` - Minimal transcription test
- `edge_two_words.wav` - Word boundary test
- **Owner:** AccuracyTest.testGoldenDatasetAccuracy()
- **Why committed:** Regression detection for minimal audio

### golden/short/ (6 fixtures)
- `perfect_male_presentation.wav` - Clean male voice baseline
- `perfect_female_technical.wav` - Clean female voice baseline
- `edge_numbers_mixed.wav` - Number transcription (123, one-two-three)
- `edge_punctuation_complex.wav` - Punctuation handling
- `accent_irish.wav` - Accent variation test
- `accent_indian.wav` - Accent variation test
- **Owner:** AccuracyTest, shell scripts
- **Why committed:** Accent fixtures cannot be synthetically generated

### golden/real/ (3 fixtures)
- `voxcore_integration.wav` - Real VoxCore usage example
- `gratitude_journal.wav` - Real voice note
- `friends_pitch.wav` - Real presentation excerpt
- **Owner:** Regression testing, accuracy benchmarks
- **Why committed:** Real-world usage patterns

## Fixtures to Remove (Candidates)

### golden-features/* (32 fixtures - ~4.5MB)
**Rationale:** Feature-specific tests should use synthetic generation or be migrated to unit tests

**Action:**
1. Review which features actually require committed audio
2. Migrate vocabulary/filler-word tests to use FullTestSuite synthetic generation
3. Keep only fixtures that test Whisper-specific behavior (not post-processing)

### golden/medium/* and golden/long/* (Review)
**Rationale:** Medium/long clips can be synthetically generated with `say` + controlled timing

**Action:**
1. Keep 1 canonical medium example (~30s)
2. Keep 1 canonical long example (~60s)
3. Remove duplicates - use synthetic generation in tests

## Synthetic Fixture Generation

Tests should generate fixtures on-the-fly using existing infrastructure:

```java
// Example from FullTestSuite.java
private Path createTestAudioWithStyle(String text, String style) throws Exception {
    Path audioFile = tempDir.resolve(style + "_test.wav");

    String rate = switch (style) {
        case "slow" -> "150";
        case "fast" -> "250";
        default -> "200";
    };

    ProcessBuilder pb = new ProcessBuilder(
        "say", "-r", rate, "-o", audioFile.toString().replace(".wav", ".aiff"), text
    );
    pb.start().waitFor(10, TimeUnit.SECONDS);

    // Convert to WAV
    ProcessBuilder convert = new ProcessBuilder(
        "ffmpeg", "-i", audioFile.toString().replace(".wav", ".aiff"),
        "-ar", "16000", "-ac", "1", audioFile.toString(), "-y"
    );
    convert.start().waitFor(10, TimeUnit.SECONDS);

    return audioFile;
}
```

### Synthetic Generation Script

Use `scripts/utilities/generate_test_data.sh` for bulk fixture regeneration:

```bash
# Generate test fixtures for development
./scripts/utilities/generate_test_data.sh --category short --count 5
```

## Ownership Map

| Fixture | Test Owner | Can Synthetically Generate? |
|---------|-----------|----------------------------|
| golden/micro/* | AccuracyTest | ✓ (but keep for regression) |
| golden/short/accent_* | AccuracyTest | ✗ (real accents required) |
| golden/short/perfect_* | AccuracyTest | ✓ (migrate to synthetic) |
| golden/real/* | Regression scripts | ✗ (real usage examples) |
| golden/natural/* | NaturalSpeechTest | ✓ (synthetic with delays) |
| golden-features/* | Feature tests | ✓ (migrate to unit tests) |

## CI Enforcement

The CI workflow enforces fixture discipline:

```yaml
- name: Check fixture size limit
  run: |
    SIZE=$(git ls-files tests/fixtures | grep -E '\.(wav|mp3|m4a)$' | xargs du -ch | tail -1 | cut -f1)
    if [ "${SIZE%M}" -gt 10 ]; then
      echo "Fixture size $SIZE exceeds 10MB limit"
      exit 1
    fi
```

## Migration Plan

**Phase 1: Fixture Audit (Current)**
- ✓ Document essential fixtures
- ✓ Identify removal candidates
- ✓ Create ownership map

**Phase 2: Synthetic Migration**
- Migrate golden-features/* tests to use FullTestSuite synthetic generation
- Remove duplicate medium/long fixtures
- Keep only canonical examples

**Phase 3: Test Consolidation**
- Migrate shell scripts to JUnit tests with synthetic fixtures
- Remove orphaned fixtures (no test owner)
- Enforce 10MB hard limit in CI

**Target State:**
- ~15 essential committed WAV files (~3MB)
- All other tests use synthetic generation
- 100% ownership coverage (every fixture has a test)
- CI enforces 10MB hard limit

## Questions?

- **Why keep any fixtures?** Some edge cases (accents, real usage) cannot be synthetically generated
- **Why 10MB limit?** Keeps repo lightweight, forces discipline
- **What about baselines/?** Local-only, .gitignored, used for regression comparison
- **How to regenerate?** Use `./scripts/utilities/generate_test_data.sh` or FullTestSuite methods
