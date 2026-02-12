# Performance Benchmarks

VoxCore performance has improved significantly across versions, from multi-second Python transcriptions to sub-second local processing with whisper-cpp.

## Summary

| Version | Transcription Speed | Key Improvement | vs Baseline |
|---------|---------------------|-----------------|-------------|
| **0.1.0** | 5-8 seconds | Initial release (openai-whisper) | Baseline |
| **0.2.0** | 3-5 seconds | Added punctuation restoration | ~40% faster |
| **0.3.0** | <1 second | **whisper-cpp integration** | **5-10x faster** |
| **0.5.0** | <1 second | Accuracy bump, new processors | Maintained speed |
| **0.6.0** | <1 second | Java CLI architecture | Maintained speed |
| **0.7.0** | <1s (short), ~1s (medium) | Dynamic model selection, vocabulary hints | Accuracy improvement |

## Current Architecture (v0.7.0)

```
Hammerspoon (hotkey, recording)
  → ffmpeg (16kHz mono WAV capture)
  → voxcore transcribe (Java CLI)
    → whisper-cpp (on-device STT)
    → 10-stage post-processing pipeline
  → paste to cursor
```

All processing is local. Zero network dependencies.

## Benchmark Results (v0.7.0)

### End-to-End Pipeline (Synthetic Golden Dataset)

From `tests/results/baselines/v0.7.0-golden-public.json`, run against 12 synthetic fixtures:

| Metric | Value |
|--------|-------|
| Total tests | 12 |
| Exact matches | 2 (16%) |
| Average word accuracy | 59% |
| Average transcription time | 1,083ms |
| Total time (12 fixtures) | 13s |

**Notes:**
- These are synthetic (macOS `say`) fixtures testing the full pipeline end-to-end.
- Word accuracy measures normalized word-by-word matching after removing punctuation and casing.
- Exact match rate is low because whisper-cpp introduces minor variations (hyphenation, number formatting, CamelCase splitting) that are correct but differ from the literal TTS script.
- Real-world accuracy with natural speech is typically higher than synthetic benchmarks for common phrases.

### Post-Processing Pipeline (Unit Tests)

From `AccuracyTest.java`, the 10-processor pipeline against 29 golden text cases:

| Metric | Value |
|--------|-------|
| Exact match accuracy | 100% (29/29) |
| Word Error Rate (WER) | 0.0% |
| Performance | <500ms for 100 iterations of long text |

Categories tested: merged words, sentence boundaries, capitalization, punctuation, vocabulary, disfluency removal, contractions, mixed patterns.

## Dynamic Model Selection (v0.7.0)

VoxCore automatically selects the whisper model based on recording duration:

| Duration | Model | Typical Speed | Trade-off |
|----------|-------|---------------|-----------|
| <21s | base.en | ~500ms | Fast, slightly lower accuracy |
| ≥21s | medium.en | ~1-2s | Slower, better accuracy |

The threshold and model names are configurable in `ptt_config.lua`:

```lua
DYNAMIC_MODEL = true           -- Enable/disable
MODEL_THRESHOLD_SEC = 21       -- Duration threshold
SHORT_MODEL = "base.en"        -- Fast model
LONG_MODEL = "medium.en"       -- Accurate model
```

## Vocabulary Hints (v0.7.0)

When VoxCompose is installed, learned vocabulary is automatically passed to whisper-cpp as prompt hints. This improves recognition of technical terms and proper nouns without affecting speed.

Without VoxCompose, a static prompt (`"Um, uh, like, you know."`) is used. Transcription works either way.

## Typical Use Cases

### Short Prompts (2-10 seconds)
- Model: base.en
- Transcription: 400-800ms
- Post-processing: ~50ms
- Example: "How do I fix this React rendering issue?"

### Medium Prompts (10-21 seconds)
- Model: base.en
- Transcription: 1.0-1.8s
- Post-processing: ~75ms
- Example: Explaining a bug in detail

### Long-Form (>21 seconds)
- Model: medium.en (automatic switch)
- Transcription: 4-6s
- Post-processing: ~100ms
- Example: Dictating meeting notes

## Hardware Performance

| Mac | Short (5s) | Medium (15s) | Long (60s) |
|-----|-----------|-------------|------------|
| M1 (base) | 400-600ms | 1.0-1.5s | 3-5s |
| M2 Pro | 300-500ms | 0.8-1.2s | 2.5-4s |
| Intel i7 (2019) | 800-1200ms | 2-3s | 6-9s |

Any Mac from 2018+ works. Apple Silicon provides best performance.

## Performance Tracking

### Transaction Logs

Every transcription logs metrics to `~/Documents/VoiceNotes/tx_logs/tx-YYYY-MM-DD.jsonl`:

```json
{
  "ts": "2026-02-06T19:30:00Z",
  "kind": "success",
  "model": "base.en",
  "duration_sec": 6.1,
  "tx_ms": 580,
  "transcript_chars": 67,
  "voxcore_version": "0.7.0"
}
```

### Benchmarking

```bash
# Run benchmark against public golden fixtures
scripts/utilities/benchmark_cli.sh

# Run against private golden fixtures (local only)
GOLDEN_DIR=tests/fixtures/golden scripts/utilities/benchmark_cli.sh

# Save results as JSON
BENCHMARK_OUTPUT=results.json scripts/utilities/benchmark_cli.sh

# Run Java accuracy tests
cd whisper-post-processor && ./gradlew integrationTest
```

### Regression Testing

The CI workflow (`benchmark-regression.yml`) runs benchmarks on every PR:
- Accuracy threshold: ≥50%
- Speed threshold: ≤2,000ms average
- Results posted as PR comment and uploaded as artifact

Historical baselines are committed in `tests/results/baselines/`.

---

**Last updated:** v0.7.0 (February 2026)
