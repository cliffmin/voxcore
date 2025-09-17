# Changelog

## [Unreleased]

### Phase 5: Real-time & Metrics (2024-09-17)
#### Added
- WebSocket endpoint `/ws` (streaming skeleton)
- Prometheus metrics at `/metrics`; timer for transcription

### Phase 4: Configuration Management (2024-09-17)
#### Added
- Configuration and ConfigurationManager with precedence (env > file > defaults)
- Tests for configuration loading and defaults
- Documentation for configuration at `docs/setup/configuration.md`
- Daemon now consumes config (language, whisperModel) with request > config > auto precedence

### Phase 3: Hammerspoon Bridge (2024-09-17)
#### Added
- Undertow-based HTTP daemon `PTTServiceDaemon` exposing `/health` and `/transcribe`
- Lua `java_bridge.lua` to start and call the daemon from Hammerspoon
- Integration tests for daemon endpoints (`PTTServiceDaemonTest`)

### Phase 2: Whisper Integration (2024-09-17)
#### Added
- **WhisperService interface** for unified transcription API
- **WhisperCppAdapter** implementation for fast C++ transcription
- **AudioProcessor** for comprehensive WAV file handling:
  - Audio validation and normalization (16kHz, mono, 16-bit)
  - Speech detection with silence removal (VAD)
  - Audio splitting for long recordings
  - Duration and format detection
- Automatic model selection based on audio duration
- Async transcription support with CompletableFuture
- Comprehensive test suite (WhisperServiceTest, AudioProcessorTest)
- API documentation at `docs/api/whisper-service.md`

### Phase 1: Java Conversion Foundation (2024-09-16)
#### Added
- **PunctuationProcessor** to replace Python deepmultilingualpunctuation
- **Ollama integration handler** for graceful LLM fallback
- VoxCompose wrapper with 30-second timeout configuration
- Java conversion plan (`JAVA_CONVERSION_PLAN.md`)
- Status tracking document (`JAVA_CONVERSION_STATUS.md`)
- Enhanced CI/CD pipeline with better error handling
- Best practices guide for Ollama/LLM at `docs/usage/ollama-best-practices.md`

### Previous Improvements
#### Added
- **Advanced Java post-processor with three new processors:**
  - **DisfluencyProcessor**: Removes "um", "uh", "you know", "like" and other filler words
  - **ReflowProcessor**: Merges artificially broken segments into continuous thoughts
  - **DictionaryProcessor**: Customizable word/phrase replacements via `~/.config/ptt-dictation/dictionary.json`
- Comprehensive Java-based E2E test suite using JUnit 5
- JSON input/output support for seamless Whisper integration
- Post-processing documentation at `docs/usage/post-processing.md`
- Makefile targets for Java testing (`make test-java`, `make test-java-integration`)
- Dictionary plugin architecture for custom word corrections
- Organized documentation structure (setup, usage, development)
- Organized scripts into logical directories

### Changed
- Test framework migrated from shell scripts to Java for better maintainability
- Removed hard-coded personal dictionary corrections
- Cleaned up obsolete scripts and test fixtures
- Simplified README to be a lean entry point

### Fixed
- Updated all documentation references to new paths
- Improved transcription quality by removing speech disfluencies
- Technical terms now properly capitalized (GitHub, JavaScript, API, etc.)

## [0.3.0] - 2024-09-15
### Added
- whisper-cpp integration (5-10x performance improvement)
- Smart model switching at 21-second threshold
- Java post-processor for text corrections
- Dictionary-based replacements

### Changed
- Optimized for sub-second transcription
- Improved accuracy to 80% on real-world dictation

## [0.2.0] - 2024-09-01
### Added
- Punctuation restoration with deepmultilingualpunctuation
- Audio preprocessing with FFmpeg
- Confidence-based segment filtering

## [0.1.0] - 2024-08-15
### Added
- Initial release
- Basic push-to-talk functionality
- Hammerspoon integration
- OpenAI Whisper transcription