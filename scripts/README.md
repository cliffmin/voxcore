# Scripts Directory

Organized utility scripts for the VoxCore system.

## Directory Structure

### setup/
Installation and configuration scripts:
- `install.sh` - Main installation script
- `uninstall.sh` - Clean uninstallation
- `setup_fast_whisper.sh` - Configure whisper-cpp for performance
- `migrate_dictionary.sh` - Migrate personal corrections to external file
- `auto_select_audio_device.sh` - Auto-configure audio input device

### testing/
Test and validation scripts:
- `test_accuracy.sh` - Test transcription accuracy
- `test_performance.sh` - Performance benchmarking
- `test_integration.sh` - Full integration testing
- `test_dictionary_plugin.sh` - Test dictionary plugin system
- `e2e_test.sh` - End-to-end testing
- `quick_benchmark.sh` - Quick performance check

### analysis/
Log analysis and monitoring:
- `analyze_durations.py` - Analyze recording durations
- `analyze_logs.py` - Parse and analyze transcription logs
- `analyze_performance.sh` - Performance metrics analysis
- `compare_benchmarks.py` - Compare benchmark results

### utilities/
Utility scripts:
- `punctuate.py` - Add punctuation to text (used by main system)
- `generate_test_data.sh` - Generate synthetic test data

### diagnostics/
System diagnostics (preserve existing structure)

### metrics/
Performance metrics (preserve existing structure)
