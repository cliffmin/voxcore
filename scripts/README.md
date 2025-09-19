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
- `daemon_health.sh` - Check daemon health and endpoints
- `debug_recording.sh` - Audio device debugging (system-specific)
- `test_f13_modes.sh` - Keyboard shortcut testing (macOS-specific)

Most legacy shell tests were migrated to Java. See `testing/MIGRATION.md` and use:
- `make test-java` (unit tests)
- `make test-java-integration` (E2E integration)
- `make test-java-all` (unit + integration)

Additional E2E and benchmarks live under `tests/integration/`.

### analysis/
Log analysis and monitoring:
- `analyze_durations.py` - Analyze recording durations
- `analyze_logs.py` - Parse and analyze transcription logs
- `analyze_performance.sh` - Performance metrics analysis
- `compare_benchmarks.py` - Compare benchmark results

### utilities/
Utility scripts:
- `generate_test_data.sh` - Generate synthetic test data

### diagnostics/
System diagnostics (preserve existing structure)

### metrics/
Performance metrics (preserve existing structure)
