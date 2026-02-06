# Changelog

## [Unreleased]

## [0.7.0] - 2026-02-06

### Added
- **Dynamic model selection**: Automatically uses `base.en` for short recordings (<21s) and `medium.en` for longer recordings. Configurable threshold, model names, and on/off toggle via `ptt_config.lua`.
- **VoxCompose vocabulary integration**: Learned vocabulary is automatically exported from VoxCompose and fed to Whisper as prompt hints, improving transcription accuracy for technical terms and proper nouns.
- **Debug mode**: New `DEBUG_MODE` config option passes `--debug` to VoxCore CLI for verbose output when troubleshooting.
- Model name logged in transaction JSONL for per-recording performance analysis.

### Changed
- Config sample (`ptt_config.lua.sample`) cleaned up: removed deprecated v1 options, added new model selection and debug settings, clearer documentation.

### Fixed
- Transaction log version now correctly reports `v0.7.0` (was hardcoded to `v0.6.0`).

### Performance
- Short recordings (<21s) use `base.en` model (~500ms transcription) instead of always defaulting to a single model. Longer recordings automatically upgrade to `medium.en` for better accuracy.

## [0.6.1] - 2026-02-06

### Added
- Golden test audio fixtures (25 synthetic WAV files) for accuracy testing
- CI/CD install and upgrade test workflows (runs on PRs and main branch)
- Plugin contract tests and mock plugin for verifying plugin integration
- Performance baseline establishment and comparison scripts
- VoxCompose version filtering support in `compare_versions.py` (exclude/include by version)
- Ecosystem section in README linking VoxCore, VoxCompose, and homebrew-tap

### Changed
- build: adopt Gradle Version Catalog for whisper-post-processor dependencies (internal; no user-visible changes)
- `compare_versions.py`: Now excludes VoxCompose recordings by default for clean VoxCore metrics (use `--include-voxcompose` to include)
- Consolidated testing documentation into single docs/development/testing.md
- Dependabot: monthly cadence, grouped updates, auto-merge for minor/patch

### Fixed
- Hammerspoon push-to-talk visual indicator: Replaced broken frame modification animation with smooth ripple effect (expanding rings that fade out)
- Audio device detection: Now resolves microphone by name instead of index, preventing iPhone Continuity from hijacking recordings when connected (macOS 15+ issue)
- Gradle Shadow plugin compatibility (downgraded to 8.3.9 for Gradle 8.5)
- CI test memory footprint (removed 500MB allocation in WhisperServiceTest)

### Removed
- Deprecated Python punctuation script (scripts/utilities/punctuate.py) and documentation references; Java PunctuationProcessor is the supported path.
- ContextProcessor has been removed from VoxCore (daemon streaming pipeline), aligning with a stateless core. Adaptive/contextual casing moves to VoxCompose. No behavior change to the default CLI path.
- Removed AI tool configuration files (.cursor/, .claude/) from repository tracking
- Archived deprecated documentation: daemon API reference, PTT daemon docs, security checklist

## [0.6.0] - 2025-12-11 (Phase 1: Java CLI + Vocabulary Integration)
### Highlights
- **🎯 Major architecture upgrade**: Core business logic migrated from Lua to Java
- **Standalone CLI**: New `voxcore` command with transcription and config validation
- **Improved transcription output**: Fixed Whisper output parsing (previously truncated)
- **Vocabulary support**: Dynamic vocabulary loading from VoxCompose-generated files
- **Better testability**: 26 unit tests for config system (PathExpander, DirectoryValidator)

### Added
- **VoxCore CLI** (`voxcore` command-line interface)
  - `voxcore transcribe <audio.wav>` - Transcribe audio files with post-processing
  - `voxcore config validate` - Validate configuration files
  - `voxcore config show` - Display effective configuration
  - `--no-post-process` flag to skip post-processing pipeline
- **Java Config System**
  - PathExpander: Tilde (~) and environment variable expansion ($HOME, ${VAR})
  - DirectoryValidator: Automatic directory creation and writability checks
  - VoxCoreConfig: JSON config loading from multiple locations
  - Config priority: ~/.config/voxcore/config.json → ~/.voxcore.json → system-wide
- **Transcription Engine**
  - WhisperInvoker: whisper-cpp binary detection and invocation
  - TranscriptionService: Orchestrates Whisper + post-processing
  - Vocabulary hints: Loads from ~/.config/voxcompose/vocabulary.txt
  - Model path resolution (handles .en suffix, Homebrew paths)
- **Build System**
  - Gradle Shadow plugin for fat JAR packaging
  - `./gradlew buildAll` creates dist/voxcore.jar + wrapper script
  - Separate executable: dist/voxcore

### Fixed
- **Whisper output parsing**: Previously returned only "." due to incorrect --output-txt flag usage
- **Model path resolution**: Now correctly finds Homebrew-installed models (strips .en suffix)
- **Whisper invocation**: Uses --no-timestamps for cleaner plain text output
- **Metadata handling**: Properly separates transcription (stdout) from metadata (stderr)

### Changed
- Post-processing pipeline now integrated into Java CLI (previously Lua-only)
- Config system moved from Lua to Java (backward compatible with existing configs)
- Hammerspoon remains as thin macOS glue layer (~200 lines) for hotkeys, recording, paste

### Architecture Notes
- **Hammerspoon role**: Handles macOS-specific features (hotkeys, audio recording, paste)
- **Java CLI role**: Business logic (config, transcription, post-processing)
- **Integration**: Hammerspoon will call `voxcore transcribe` (Phase 1.1)
- **Goal**: Testable, maintainable, stateless architecture

### Testing
- 26 unit tests passing (PathExpanderTest: 10, DirectoryValidatorTest: 16)
- End-to-end transcription verified with real audio files
- CI/CD pipeline validates all changes before merge

### Breaking Changes
- None (backward compatible - Hammerspoon integration unchanged for now)

### Next Phase: 1.1 (Hammerspoon Integration)
- Update Hammerspoon to call Java CLI
- VoxCompose vocabulary export command
- Remove ~80% of Lua business logic

## [0.5.0] - 2025-11-26
### Highlights
- **Improved transcription quality**: Fixed incorrect sentence boundaries (no more "the. Project. Vox. Core")
- **Better proper noun handling**: CamelCase compounds like VoxCore preserved correctly
- **Developer experience**: `make transcribe` now auto-selects latest recording

### Added
- SentenceBoundaryProcessor: Articles/prepositions no longer trigger false sentence breaks
- SentenceBoundaryProcessor: CamelCase detection prevents splitting compound names (VoxCore, GitHub)
- MergedWordProcessor: Sentence-starter detection (Then, Now, However) for proper boundaries
- MergedWordProcessor: 25+ new merged word patterns (willbe, shouldbe, kindof, sortof, etc.)
- DictionaryProcessor: VoxCore ecosystem terms (VoxCore, VoxCompose, Hammerspoon, Whisper)
- `make transcribe` auto-selects latest recording from ~/Documents/VoiceNotes/ when no path given
- Real recording test fixtures in tests/fixtures/golden/real/ (local only, gitignored)

### Fixed
- Sentence boundaries no longer incorrectly added after articles ("the Project" not "the. Project")
- Double post-processing removed from transcribe_and_paste.sh (daemon already processes)
- CamelCase proper nouns no longer split ("VoxCore" stays "VoxCore", not "Vox. Core")

### Changed
- transcribe_and_paste.sh simplified: uses daemon output directly without re-processing

## [0.4.0] - 2025-09-17
- Java service (HTTP/WS) with configuration and metrics
- Reliable start-of-speech capture (reduced first-word truncation due to warm service)
- Config precedence (request > env/file > defaults) and pipeline toggles applied in CLI/daemon
- ContextProcessor (learns term casing) used in streaming pipeline
- WebSocket streaming marked experimental; HTTP endpoints considered stable

### Phase 5: Real-time & Metrics (2024-09-17)
#### Added
- WebSocket endpoint `/ws` (incremental processing via pipeline; returns `{ processed: ... }`)
- ContextProcessor that learns term casing from recent text (used in streaming pipeline)
- Prometheus metrics at `/metrics`; timer for transcription; room to add counters

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