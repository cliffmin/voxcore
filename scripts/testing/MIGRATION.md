# Test Migration Plan: Shell to Java

## Scripts to REMOVE (functionality moved to Java)

### Fully migrated to Java tests:
- `test_accuracy.sh` → `AccuracyTest.java`
- `test_accuracy_enhanced.sh` → `AccuracyTest.java`
- `test_performance.sh` → `PerformanceTest.java`
- `quick_benchmark.sh` → `PerformanceTest.java`
- `test_whisper_cpp.sh` → `WhisperIntegrationTest.java`
- `test_integration.sh` → `WhisperIntegrationTest.java`
- `test_dictionary_plugin.sh` → `DictionaryPluginTest.java`
- `test_java_processor.sh` → Unit tests in processors package
- `test_e2e_with_java.sh` → `E2EIntegrationTest.java`

### Obsolete/redundant:
- `test_bug_fixes.sh` - Bug fix verification should be in unit tests
- `e2e_test.sh` - Replaced by Java E2E tests

## Scripts to KEEP (simple smoke tests)

### Hardware/system interaction:
- `debug_recording.sh` - Audio device debugging (system-specific)
- `test_f13_modes.sh` - Keyboard shortcut testing (macOS-specific)

## Migration Complete

All complex logic has been moved to Java tests with:
- Better error handling
- Type safety
- IDE support
- Easier maintenance
- Unified test reporting

Run all Java tests with:
```bash
make test-java-all
```