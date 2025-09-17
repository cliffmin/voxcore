# Whisper Service API

## Overview

The Whisper Service provides a unified interface for transcribing audio using different Whisper implementations (whisper.cpp, OpenAI Whisper). It handles model selection, audio validation, and result parsing.

## Architecture

```
WhisperService (interface)
├── WhisperCppAdapter     - Fast C++ implementation
├── OpenAIWhisperAdapter   - Python-based implementation
└── AudioProcessor         - Audio file handling
```

## Usage

### Basic Transcription

```java
// Initialize service
WhisperService whisper = new WhisperCppAdapter();

// Configure options
TranscriptionOptions options = new TranscriptionOptions.Builder()
    .model("base.en")
    .language("en")
    .timestamps(true)
    .build();

// Transcribe audio
Path audioFile = Paths.get("/path/to/audio.wav");
TranscriptionResult result = whisper.transcribe(audioFile, options);

// Access results
String text = result.getText();
List<Segment> segments = result.getSegments();
double duration = result.getDuration();
```

### Async Transcription

```java
CompletableFuture<TranscriptionResult> future = 
    whisper.transcribeAsync(audioFile, options);

future.thenAccept(result -> {
    System.out.println("Transcription: " + result.getText());
});
```

### Model Selection

```java
AudioProcessor processor = new AudioProcessor();
double duration = processor.getDuration(audioFile);

// Automatic model selection based on duration
String model = whisper.detectModel(duration);
```

## Audio Processing

### Validation

```java
AudioProcessor processor = new AudioProcessor();

// Validate for Whisper compatibility
if (processor.validateForWhisper(audioFile)) {
    // Audio is suitable for transcription
}

// Get audio information
AudioInfo info = processor.getAudioInfo(audioFile);
System.out.println("Duration: " + info.duration + " seconds");
System.out.println("Sample rate: " + info.sampleRate + " Hz");
```

### Normalization

```java
// Convert to Whisper-compatible format (16kHz, mono, 16-bit)
Path normalized = processor.normalizeForWhisper(
    inputPath, 
    outputPath
);
```

### Speech Detection

```java
// Detect speech ranges (VAD)
double silenceThresholdDb = -30.0;
List<TimeRange> speechRanges = processor.detectSpeechRanges(
    audioFile, 
    silenceThresholdDb
);

// Split audio by speech ranges
List<Path> chunks = processor.splitAudio(
    audioFile, 
    speechRanges, 
    outputDir
);
```

## Configuration

### Model Selection Strategy

| Duration | Model | Use Case |
|----------|-------|----------|
| < 10s | tiny.en | Quick responses, real-time |
| 10-30s | base.en | Balanced speed/quality |
| 30-300s | small.en | Better accuracy |
| > 300s | medium.en | Best quality |

### Transcription Options

| Option | Default | Description |
|--------|---------|-------------|
| model | base.en | Whisper model to use |
| language | en | Source language |
| timestamps | true | Include word timestamps |
| outputFormat | json | Output format (json, txt, vtt) |
| beamSize | 5 | Beam search width |
| temperatureIncrement | 0.2 | Temperature for sampling |
| noSpeechThreshold | true | Filter out non-speech |

## Error Handling

```java
try {
    TranscriptionResult result = whisper.transcribe(audioFile, options);
} catch (TranscriptionException e) {
    if (e.getMessage().contains("timeout")) {
        // Handle timeout
    } else if (e.getMessage().contains("Invalid audio")) {
        // Handle invalid audio
    }
}
```

## Performance Considerations

### Memory Usage
- Tiny model: ~39MB
- Base model: ~74MB
- Small model: ~244MB
- Medium model: ~769MB

### Processing Time
- Typical ratio: 1:1 to 1:3 (1 minute audio = 1-3 minutes processing)
- Faster with whisper.cpp
- Use smaller models for real-time requirements

## Integration with PTT

The Whisper Service integrates with the push-to-talk system:

1. Audio recorded via FFmpeg
2. Saved as WAV file
3. Validated by AudioProcessor
4. Model selected based on duration
5. Transcribed by WhisperService
6. Text post-processed by pipeline

## Testing

```bash
# Run Whisper service tests
gradle test --tests WhisperServiceTest

# Run audio processor tests
gradle test --tests AudioProcessorTest

# Integration tests
gradle integrationTest
```

## Troubleshooting

### Service Not Available
- Check whisper binary path
- Verify models are downloaded
- Ensure FFmpeg is installed

### Poor Transcription Quality
- Use larger model
- Normalize audio to 16kHz
- Check audio quality (noise, volume)
- Adjust beam size

### Timeout Issues
- Increase timeout setting
- Use smaller model
- Split long audio into chunks