# Changelog

## [Unreleased]
### Added
- Dictionary plugin architecture for custom word corrections
- Organized documentation structure (setup, usage, development)
- Organized scripts into logical directories

### Changed
- Removed hard-coded personal dictionary corrections
- Cleaned up obsolete scripts and test fixtures
- Simplified README to be a lean entry point

### Fixed
- Updated all documentation references to new paths

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