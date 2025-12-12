# VoxCore Testing Strategy

## Overview

VoxCore uses **golden dataset testing** to establish performance baselines and prevent regressions. Each feature has its own golden dataset that tracks accuracy and speed metrics over time.

## Testing Philosophy

- **Baselines, not perfection** - Tests establish baseline metrics (e.g., 43% word accuracy), not 100% pass rates
- **Accuracy + Speed** - Track both transcription accuracy percentage and processing time
- **Regression prevention** - CI/CD ensures performance doesn't drop below baseline thresholds
- **Feature-specific** - Each feature has dedicated golden datasets to isolate improvements

## Golden Dataset Structure

### Private Test Data (Local Development)
```
tests/fixtures/golden-features/  # .gitignored - contains personal audio
├── baseline/           # General transcription baseline (current 43% avg accuracy)
├── filler-words/       # Filler word removal ("um", "uh", "like", "you know")
├── word-separation/    # Compound word handling ("GitHub", "push-to-talk", "NoSQL")
└── vocabulary/         # Technical term accuracy with vocabulary hints
```

### Public Test Data (CI/CD - Optional)
```
tests/fixtures/golden-public/  # Tracked in git, safe for public repos
├── baseline/          # Synthetic/generated test audio
├── filler-words/      # Generated test cases
├── word-separation/   # Generic technical terms
└── vocabulary/        # Non-personal examples
```

**Note**: The `golden-features/` directory contains personal audio recordings and is excluded from version control. For CI/CD regression tests, you can optionally create `golden-public/` with synthetic or publicly-acceptable test audio.

### File Format

Each test includes multiple files tracking before/after states:

- `{test}.wav` - Audio file
- `{test}.txt` - Expected golden transcript (ground truth)
- `{test}.raw.txt` - Raw Whisper output (before post-processing)
- `{test}.processed.txt` - VoxCompose post-processed output
- `{test}.json` - Test metadata
- `{test}.whisper.json` - Whisper output metadata

## Feature Benchmarks

### 1. Baseline (General Transcription)

**Intent**: Measure core VoxCore CLI transcription accuracy without feature-specific optimization.

**Dataset**: Mixed real-world audio (short, medium, long, challenging scenarios)

**Current Baseline** (as of 2025-12-06):
- Average word accuracy: 43%
- Exact matches: 15% (5/32 tests)
- Average speed: 906ms per transcription
- Total tests: 32

**Regression Threshold**:
- Accuracy must not drop below 38% (-5% tolerance)
- Speed must not exceed 1200ms average (+300ms tolerance)

**What changed**:
- **Before**: No baseline established
- **After**: Established 43% accuracy baseline with vocabulary support

---

### 2. Filler Word Removal

**Intent**: Verify that common speech disfluencies are intelligently removed for cleaner output.

**Target Words**: "um", "uh", "like", "you know", "basically", "actually"

**Dataset**: `tests/fixtures/golden/filler-words/`
- Natural speech with heavy filler word usage
- Professional presentations with occasional fillers
- Casual conversations with frequent disfluencies

**Current Baseline**: TBD (to be established)

**Expected Behavior**:
- `.raw.txt` contains filler words (Whisper includes them)
- `.txt` (expected) omits filler words for cleaner output
- Test measures whether output matches clean expected transcript

**Regression Threshold**: TBD after baseline establishment

**What changed**:
- **Before**: Whisper includes all filler words verbatim
- **After**: (Future) VoxCompose post-processing removes fillers intelligently

---

### 3. Word Separation

**Intent**: Test compound technical terms and proper spacing/capitalization.

**Target Terms**:
- Compound words: "GitHub" (not "Git Hub"), "NoSQL" (not "No SQL")
- Hyphenated: "push-to-talk", "voice-to-text"
- Operating systems: "macOS" (not "Mac OS"), "iOS" (not "I OS")
- Capitalization: "JavaScript" (not "Java Script")

**Dataset**: `tests/fixtures/golden/word-separation/`
- Technical dictation with compound terms
- Product names and technical vocabulary
- Mixed capitalization requirements

**Current Baseline**: TBD (to be established)

**Expected Behavior**:
- `.raw.txt` may have spacing errors (e.g., "Git Hub")
- `.processed.txt` corrects to proper form (e.g., "GitHub")
- `.txt` is ground truth with correct spacing

**Regression Threshold**: TBD after baseline establishment

**What changed**:
- **Before**: Raw Whisper output with spacing errors
- **After**: VoxCompose corrections apply learned patterns

---

### 4. Vocabulary Enhancement

**Intent**: Measure impact of vocabulary hints on technical term accuracy.

**Dataset**: `tests/fixtures/golden/vocabulary/`
- Technical terms from user's vocabulary file
- Rare proper nouns (company names, APIs)
- Domain-specific jargon

**Current Baseline**: TBD (to be established)

**Test Methodology**:
1. Run benchmark WITHOUT vocabulary file → baseline accuracy
2. Run benchmark WITH vocabulary file → enhanced accuracy
3. Compare delta to measure vocabulary impact

**Expected Improvement**: +10-20% accuracy on technical terms

**Regression Threshold**:
- With vocabulary must be ≥ 5% better than without vocabulary

**What changed**:
- **Before**: No vocabulary hints, Whisper guesses technical terms
- **After**: VoxCompose exports vocabulary, Whisper uses hints via INITIAL_PROMPT

---

## Running Benchmarks

### Full Baseline Benchmark

```bash
# From VoxCore repository root
./scripts/utilities/benchmark_cli.sh
```

**Output**:
```
=== Benchmark Results ===
Total tests:    32
Exact matches:  5 (15%)
Avg accuracy:   43%
Avg time:       906ms
Total time:     29000ms
```

### Feature-Specific Benchmark

```bash
# Filler word removal tests
GOLDEN_DIR=tests/fixtures/golden/filler-words ./scripts/utilities/benchmark_cli.sh

# Word separation tests
GOLDEN_DIR=tests/fixtures/golden/word-separation ./scripts/utilities/benchmark_cli.sh

# Vocabulary enhancement tests
GOLDEN_DIR=tests/fixtures/golden/vocabulary ./scripts/utilities/benchmark_cli.sh
```

---

## CI/CD Regression Tests

### GitHub Actions Workflow

Location: `.github/workflows/benchmark-regression.yml`

**Triggers**:
- Every PR to `main`
- Manual workflow dispatch
- Scheduled weekly run

**Tests Run**:
1. Baseline benchmark (must meet thresholds)
2. Filler word removal (feature-specific)
3. Word separation (feature-specific)
4. Vocabulary enhancement (feature-specific)

**Failure Conditions**:
- Accuracy drops >5% below baseline
- Speed increases >300ms above baseline
- Any feature-specific regression

**Artifact Upload**:
- Benchmark results JSON
- Comparison with previous run
- Performance trend charts

---

## Adding New Tests

### 1. Record Audio
```bash
# Use VoxCore to record test audio
ffmpeg -f avfoundation -i ":0" -ac 1 -ar 16000 test.wav
```

### 2. Create Expected Transcript
Manually transcribe the audio to create `test.txt` (ground truth).

### 3. Generate Raw Whisper Output
```bash
voxcore transcribe test.wav > test.raw.txt
```

### 4. Add Test Metadata
Create `test.json`:
```json
{
  "name": "test_name",
  "feature": "baseline|filler-words|word-separation|vocabulary",
  "duration_ms": 3000,
  "expected_accuracy": 85,
  "notes": "Description of what this test covers"
}
```

### 5. Run Benchmark
```bash
./scripts/utilities/benchmark_cli.sh
```

---

## Interpreting Results

### Accuracy Percentage

Word accuracy is calculated as:
```
accuracy = (matching_words / expected_word_count) * 100
```

- **90-100%**: Excellent - minor punctuation differences only
- **70-89%**: Good - some technical term errors
- **50-69%**: Fair - multiple errors but generally understandable
- **<50%**: Poor - significant transcription issues

### Speed Metrics

- **< 500ms**: Excellent (real-time capable)
- **500-1000ms**: Good (acceptable for most use cases)
- **1000-2000ms**: Fair (noticeable delay)
- **> 2000ms**: Poor (need optimization)

### Exact Match Rate

Percentage of tests with 100% word accuracy (ignoring punctuation).
- Current: 15% (5/32 tests)
- Target: 25% after vocabulary improvements

---

## Future Improvements

### Planned Features & Expected Baselines

1. **Punctuation Accuracy** (not yet tested)
   - Dedicated dataset for punctuation placement
   - Measure periods, commas, question marks

2. **Speaker Diarization** (future)
   - Multi-speaker audio tests
   - Accuracy of speaker change detection

3. **Noise Robustness** (future)
   - Background noise test scenarios
   - Accuracy degradation under noise

4. **Language Mixing** (future)
   - Code terms in natural speech
   - Technical acronyms in sentences

---

## Maintenance

### Updating Baselines

When intentional improvements are made, update baselines:

1. Run full benchmark suite
2. Document changes in git commit
3. Update this document with new baseline metrics
4. Update CI/CD regression thresholds

### Golden Dataset Curation

- Review failing tests quarterly
- Update `.txt` files if ground truth was incorrect
- Remove outdated/irrelevant tests
- Add new tests for edge cases discovered in production

---

## Questions?

See also:
- [CHANGELOG.md](../CHANGELOG.md) - Version history and improvements
- [docs/development/ACCURACY_IMPROVEMENT_PLAN.md](development/ACCURACY_IMPROVEMENT_PLAN.md) - Internal improvement tracking
- [README.md](../README.md) - General project documentation
