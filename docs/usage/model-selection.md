# Whisper Model Configuration Guide

## Quick Start

The default configuration now uses **medium.en** for the best accuracy based on our comprehensive testing. This provides:
- 16.86% Word Error Rate (15% better than base.en)
- Excellent technical term recognition
- Acceptable processing times (8-22 seconds for short clips)

## Available Models

| Model | Size | WER | Speed | Best For |
|-------|------|-----|-------|----------|
| base.en | 141 MB | 19.89% | Fast (3-8s) | Quick notes, real-time feedback |
| small.en | 488 MB | 19.19% | Moderate (4-10s) | Not recommended (minimal improvement) |
| medium.en | 1.5 GB | 16.86% | Slower (8-22s) | **Recommended** - Technical documentation |
| large-v3 | 3.1 GB | ~15% | Slowest (20-60s) | Critical accuracy needs |

## Configuration Options

### Option 1: Single Model (Default)

Edit `~/.hammerspoon/ptt_config.lua`:

```lua
-- Use medium.en for all recordings (recommended)
WHISPER_MODEL = "medium.en",
```

### Option 2: Dynamic Model Selection

Use different models based on recording duration:

```lua
-- Use fast model for short clips, accurate for long
WHISPER_MODEL = "base.en",  -- Default/fallback

MODEL_BY_DURATION = {
  ENABLED = true,            -- Enable dynamic selection
  SHORT_SEC = 12.0,          -- Threshold in seconds
  MODEL_SHORT = "base.en",   -- Fast model for <= 12s
  MODEL_LONG = "medium.en",  -- Accurate for > 12s
},
```

### Option 3: Mode-Based Selection

Different models for hold vs toggle mode:

```lua
-- Fast for hold-to-talk, accurate for toggle mode
WHISPER_MODEL = "base.en",  -- For F13 hold

-- In the LLM_REFINER section, you could use medium.en
-- for toggle mode recordings before refinement
```

## Performance Considerations

### CPU vs GPU

The system auto-detects Metal Performance Shaders (MPS) support on Apple Silicon. GPU acceleration provides:
- 2-3x faster inference for medium/large models
- Lower battery impact for long recordings
- Requires macOS 12.3+

### Memory Usage

Approximate memory requirements:
- base.en: ~500 MB
- small.en: ~1 GB
- medium.en: ~2.5 GB
- large-v3: ~5 GB

### First-Run Latency

Models are downloaded on first use. Initial download times:
- base.en: ~1 minute
- medium.en: ~3 minutes
- large-v3: ~5 minutes

Models are cached in `~/.cache/whisper/`

## Optimization Tips

### For Speed
1. Use base.en with dictionary replacements
2. Enable dynamic model selection
3. Ensure MPS is enabled on Apple Silicon
4. Consider reducing beam_size to 1

### For Accuracy
1. Use medium.en or large-v3
2. Add technical terms to INITIAL_PROMPT
3. Keep dictionary replacements enabled
4. Use beam_size of 3-5

### Balanced Approach
```lua
-- Recommended configuration
WHISPER_MODEL = "medium.en",

-- Keep post-processing for edge cases
DICTIONARY_REPLACE = {
  ["sim links"] = "symlinks",
  ["no sequel"] = "NoSQL",
  -- ... your custom replacements
},

-- Add your domain vocabulary
INITIAL_PROMPT = table.concat({
  "Software development, GitHub, Jira, NoSQL, symlinks, ",
  "Your specific technical terms here..."
}),
```

## Testing Your Configuration

### 1. Test model accuracy
```bash
# Run Java tests (unit + integration)
make test-java-all
```

### 2. Test real-world performance
```bash
# Record a test clip
# Press F13 and say: "Check the GitHub repository for symlinks in the NoSQL database"
# Check if technical terms are recognized correctly
```

### 3. Monitor logs
```bash
# Check transcription logs for model selection
tail -f ~/Documents/VoiceNotes/tx_logs/$(date +%Y/%m/%d)/*.jsonl | jq .
```

## Troubleshooting

### Model not found
```bash
# List available models
ls ~/.cache/whisper/

# Force re-download
rm -rf ~/.cache/whisper/medium.en*
```

### Slow performance
1. Check Activity Monitor for CPU/Memory usage
2. Verify MPS is enabled (check logs for "device: mps")
3. Consider using dynamic model selection
4. Close other resource-intensive applications

### Poor accuracy
1. Verify model is correctly specified in config
2. Check INITIAL_PROMPT includes your domain terms
3. Update DICTIONARY_REPLACE for consistent mishears
4. Consider upgrading to large-v3 for critical use

---

*Last Updated: September 8, 2025*
