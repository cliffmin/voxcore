# Installing Whisper Models

VoxCore uses whisper-cpp for fast, on-device transcription. The whisper-cpp binary is installed via Homebrew, but **model files must be downloaded separately**.

## Quick Install

```bash
# Download base.en model (recommended for most use)
mkdir -p /opt/homebrew/share/whisper-cpp
cd /opt/homebrew/share/whisper-cpp
curl -L -o ggml-base.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin

# Optional: Download medium.en for longer recordings (>21 seconds)
curl -L -o ggml-medium.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin
```

## Model Selection

VoxCore automatically selects models based on audio duration:

- **Short recordings (<21 seconds)**: Uses `base.en` (faster, ~500ms)
- **Long recordings (≥21 seconds)**: Uses `medium.en` (more accurate, ~3-5 seconds)

This is configured in `VoxCoreConfig` and can be overridden in your config file.

## Available Models

| Model | Size | Speed | Accuracy | Use Case |
|-------|------|-------|----------|----------|
| `tiny.en` | ~75 MB | Fastest | Good | Quick tests |
| `base.en` | ~150 MB | Fast | Very Good | **Recommended** (default) |
| `small.en` | ~500 MB | Medium | Excellent | Better accuracy |
| `medium.en` | ~1.5 GB | Slower | Best | Long recordings |

**Recommendation:** Start with `base.en`. It provides excellent accuracy for most use cases and is fast enough for real-time transcription.

## Download All Models (Optional)

```bash
cd /opt/homebrew/share/whisper-cpp

# Download all English models
for model in tiny base small medium; do
  echo "Downloading ${model}.en..."
  curl -L -o "ggml-${model}.bin" "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-${model}.en.bin"
done
```

## Verify Installation

```bash
# Check if models are installed
ls -lh /opt/homebrew/share/whisper-cpp/ggml-*.bin

# Test with VoxCore
voxcore config show
# Should show: whisper_model: base.en
```

## Troubleshooting

### Model Not Found Error

**Error:** `failed to open 'base.en'` or `model not found`

**Solution:**
1. Verify model file exists:
   ```bash
   ls -la /opt/homebrew/share/whisper-cpp/ggml-base.bin
   ```

2. If missing, download it (see Quick Install above)

3. Check file permissions:
   ```bash
   chmod 644 /opt/homebrew/share/whisper-cpp/ggml-*.bin
   ```

### Wrong Model Path

If models are in a different location, configure the path in `~/.config/voxcore/config.json`:

```json
{
  "whisper_model": "/path/to/your/ggml-base.bin"
}
```

## Model Sources

Models are downloaded from:
- **Primary:** [Hugging Face - ggerganov/whisper.cpp](https://huggingface.co/ggerganov/whisper.cpp)
- **Format:** GGML binary format (optimized for whisper-cpp)

## Performance Notes

- **First transcription:** Slower (~500-800ms) due to model loading
- **Subsequent transcriptions:** Fast (<1 second for short clips)
- **Model size vs speed:** Larger models are more accurate but slower
- **Memory usage:** Models are loaded into RAM during transcription

See [Performance Documentation](../performance.md) for detailed benchmarks.
