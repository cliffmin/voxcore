# Testing

## Recent Issue: Audio Device Validation (Resolved)

**Problem**: The module was failing silently when the audio device at index 1 wasn't exactly "MacBook Pro Microphone". This overly strict validation prevented recording even when valid audio devices were available.

**Root Cause**: Hardware-dependent validation that assumed a specific device name and configuration.

**Fix Applied**:
1. Made validation less strict - now only checks if ANY device exists at the configured index
2. Changed from blocking error to warning - continues with recording even if validation fails
3. Added config option `SKIP_AUDIO_VALIDATION = true` to bypass validation entirely

**Why We Didn't Have Tests**: 
- Hardware dependencies (actual audio devices)
- Hammerspoon-specific APIs not available in test environments
- External process dependencies (ffmpeg)
- Device enumeration varies between machines

This project includes comprehensive testing using a golden dataset with known-accurate transcriptions.

## Test Data Structure

```
tests/fixtures/
├── golden/          # Public test data (generated locally; gitignored)
│   ├── micro/       # < 2 seconds
│   ├── short/       # 2-10 seconds
│   ├── medium/      # 10-30 seconds
│   └── long/        # 30+ seconds
└── personal/        # Private voice data (gitignored)
```

## Golden Dataset

The golden dataset consists of synthetic audio generated using macOS text-to-speech with exactly known transcriptions. This allows us to measure accuracy objectively.

### Categories

- **Micro** (< 2s): Quick commands and greetings
- **Short** (2-10s): Technical terms, punctuation, numbers
- **Medium** (10-30s): Code descriptions, multi-sentence
- **Long** (30+s): Documentation, technical explanations

### Sample Coverage

- Technical terminology (API, JSON, GitHub)
- Punctuation and formatting
- Numbers and dates
- Acronyms and abbreviations
- Disfluencies (um, uh, etc.)
- Multi-paragraph text

## Running Tests

### Generate Golden Dataset
```bash
# Create synthetic test audio (golden fixtures are local-only and not committed)
bash scripts/utilities/generate_test_data.sh
```

### Test Suite
```bash
# Build and run all Java tests (unit + integration)
make test-java-all

# Or run separately
make test-java              # unit tests
make test-java-integration  # integration tests
```

### Results

Test results are saved to `tests/results/` with:
- Individual transcription comparisons
- Word Error Rate (WER) calculations
- Timing measurements
- Summary statistics

## Metrics

### Word Error Rate (WER)
Percentage of words that differ between reference and hypothesis transcriptions.
- 0% = Perfect transcription
- < 5% = Excellent
- 5-10% = Good
- > 10% = Needs improvement

### Performance Metrics
- Transcription speed (ms)
- Real-time factor (audio duration / processing time)
- Memory usage (optional)

## Personal Test Data

Your personal voice recordings are kept in `tests/fixtures/personal/` and are gitignored for privacy. To test with your own voice:

```bash
# Organize existing recordings
bash scripts/organize_test_data.sh

# Test against personal data
bash scripts/test_personal.sh  # Create this if needed
```

## Continuous Testing

For development:
1. Run accuracy tests before commits
2. Compare models for performance/accuracy trade-offs
3. Test edge cases (background noise, accents, speed)

## CI Policy (Solo-friendly)
- Required and fast: Quick Validation, Java Compilation, Java Tests, Quality Checks
- Non-required by default: Integration Tests (run on PRs but do not block; can be scheduled nightly)
- Concurrency enabled: new pushes cancel in-progress runs for the same branch
- “Require branch to be up to date” is disabled in protection (Merge Queue recommended if available)
- PR titles follow Conventional Commits: (feat|fix|docs|refactor|test|chore|style|perf)(scope?): description


<!-- ci/streamline-protection: trigger sync -->

## Expected Results

With `base.en` model on golden dataset:
- WER: < 5% for clear synthetic speech
- Speed: 5-10x faster than real-time
- Perfect accuracy on simple commands

## Troubleshooting

- **High WER**: Check audio quality, try larger model
- **Slow performance**: Verify CPU mode, check background processes
- **Missing transcriptions**: Ensure Whisper is installed correctly

## Adding Test Cases

To add new test cases to the golden dataset:

1. Edit `scripts/utilities/generate_test_data.sh`
2. Add new `generate_sample` calls with exact text
3. Regenerate dataset
4. Keep golden files locally (do not commit them to the repository)
