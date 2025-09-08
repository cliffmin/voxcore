# Internal Metrics and Logging

## Overview

The system logs comprehensive metrics for each transcription to enable performance analysis and debugging.

## Log Structure

### Location
- Daily JSONL files: `~/Documents/VoiceNotes/tx_logs/tx-YYYY-MM-DD.jsonl`
- One JSON object per line for streaming processing
- Automatic daily rotation

### Event Types

#### `success` - Successful transcription
```json
{
  "ts": "2025-09-08T06:08:35Z",
  "kind": "success",
  "app": "macos-ptt-dictation",
  "model": "base.en",
  "device": "cpu",
  "beam_size": 3,
  "wav": "/path/to/audio.wav",
  "wav_bytes": 3379278,
  "duration_sec": 105.6,
  "tx_ms": 5451,
  "transcript_chars": 345,
  "transcript": "actual text",
  "session_kind": "hold",
  "output_mode": "paste"
}
```

#### `error` - Failed transcription
- Includes `stderr` field with error details
- `tx_code` with exit code

#### `timeout` - Transcription exceeded time limit
- Includes timeout duration and reason

#### `refine` - LLM refinement (optional)
- Provider, model, and refinement time

## Key Metrics Tracked

### Performance
- **duration_sec**: Recording length
- **tx_ms**: Transcription time in milliseconds
- **realtime_ratio**: duration_sec / (tx_ms/1000)
- **wav_bytes**: File size
- **transcript_chars**: Output length

### Configuration Snapshot
- Model and beam size used
- Device (cpu/mps)
- Reflow settings
- Preprocessing flags

### Quality Indicators
- **reflow_total_segments**: Whisper segments processed
- **reflow_dropped_segments**: Low-confidence segments removed
- **peak_level**: Audio peak for voice detection

## Analysis Tools

### `scripts/analyze_logs.py`
Generates comprehensive analytics report:
- Success rates
- Performance statistics
- Daily usage patterns
- Error analysis
- Model/device breakdown

Usage:
```bash
python3 scripts/analyze_logs.py
python3 scripts/analyze_logs.py --json  # Export detailed JSON
```

## Privacy Considerations

- Logs contain full transcripts (for debugging)
- Stored locally only
- Not synced or transmitted
- Add to .gitignore for public repos

## Retention Policy

No automatic cleanup. Manual management:
```bash
# Archive logs older than 30 days
find ~/Documents/VoiceNotes/tx_logs -name "*.jsonl" -mtime +30 -exec mv {} ~/backup/ \;

# Delete logs older than 90 days
find ~/Documents/VoiceNotes/tx_logs -name "*.jsonl" -mtime +90 -delete
```

## Development Uses

1. **Performance Tuning**
   - Identify slow transcriptions
   - Optimize model selection

2. **Error Patterns**
   - Track failure reasons
   - Improve error handling

3. **Usage Insights**
   - Peak usage times
   - Average session lengths
   - Feature adoption (hold vs toggle)

4. **Testing**
   - Benchmark comparisons
   - Regression detection
