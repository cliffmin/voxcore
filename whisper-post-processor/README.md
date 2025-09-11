# Whisper Post-Processor

A Java-based post-processor that fixes common Whisper transcription issues like merged words, missing punctuation, and run-on sentences.

## Features

- **Merged Word Separation**: Fixes patterns like "theyconfigure" → "they configure"
- **Sentence Boundary Detection**: Adds periods between run-on sentences
- **Smart Capitalization**: Proper case for sentences and "I"
- **Punctuation Normalization**: Fixes spacing around commas, periods, etc.
- **Extensible Pipeline**: Easy to add new processors

## Installation

### Quick Install

```bash
# Clone the repo (if not already)
git clone https://github.com/yourusername/macos-ptt-dictation.git
cd macos-ptt-dictation/whisper-post-processor

# Run the install script
./install.sh
```

This will:
1. Build the Java processor
2. Install it to `~/.local/bin/`
3. Create a wrapper script for easy command-line use
4. Configure automatic detection in Hammerspoon

### Manual Installation

```bash
# Build the JAR
gradle shadowJar

# Copy to a location of your choice
cp dist/whisper-post.jar /path/to/install/

# Optional: Add to your ptt_config.lua
POST_PROCESSOR_JAR = "/path/to/install/whisper-post.jar"
```

## Requirements

- Java 17 or later
- Gradle (for building)

Install with Homebrew:
```bash
brew install openjdk gradle
```

## Usage

### Command Line

```bash
# Process text directly
echo "theyconfigure the system" | whisper-post

# Process a file
whisper-post -f input.txt -o output.txt

# Debug mode
whisper-post --debug "test text"
```

### With Hammerspoon PTT

The post-processor integrates automatically if installed to one of these locations:
- `~/.local/bin/whisper-post.jar`
- `/usr/local/bin/whisper-post.jar`
- Relative to Hammerspoon config directory
- In your PATH as `whisper-post`

Or configure explicitly in `ptt_config.lua`:
```lua
POST_PROCESSOR_JAR = "/path/to/whisper-post.jar"
```

## Architecture

The processor uses a pipeline pattern with pluggable processors:

```
Input Text
    ↓
MergedWordProcessor (Priority: 10)
    ↓
SentenceBoundaryProcessor (Priority: 20)
    ↓
CapitalizationProcessor (Priority: 30)
    ↓
PunctuationNormalizer (Priority: 40)
    ↓
Output Text
```

## Adding New Processors

1. Implement the `TextProcessor` interface:

```java
public class MyProcessor implements TextProcessor {
    @Override
    public String process(String input) {
        // Your processing logic
        return processedText;
    }
    
    @Override
    public int getPriority() {
        return 25; // Runs between sentence and capitalization
    }
}
```

2. Add to the pipeline in `WhisperPostProcessorCLI.java`:

```java
pipeline.addProcessor(new MyProcessor());
```

## Development

```bash
# Run tests
gradle test

# Build JAR
gradle shadowJar

# Build with native image (requires GraalVM)
gradle nativeCompile
```

## Performance

- Typical processing time: 50-100ms per transcription
- Memory usage: ~50MB (JVM overhead)
- Can be compiled to native binary with GraalVM for faster startup

## License

MIT
