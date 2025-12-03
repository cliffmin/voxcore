# Plugin Testing Strategy & Best Practices

## Core Principle

**Plugin tests belong in the plugin repo. Integration tests belong in VoxCore.**

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    VoxCore (Host)                       │
│  - Core functionality tests                             │
│  - Plugin integration contract tests                    │
│  - Mock plugin tests (verify contract)                  │
└─────────────────┬───────────────────────────────────────┘
                  │
        ┌─────────┴──────────┐
        │                    │
┌───────▼─────────┐   ┌──────▼──────────┐
│  VoxCompose     │   │  Future Plugin  │
│  (Plugin)       │   │  (Plugin)        │
│                 │   │                  │
│  - Unit tests   │   │  - Unit tests    │
│  - CLI tests    │   │  - CLI tests     │
│  - Self tests   │   │  - Self tests    │
└─────────────────┘   └─────────────────┘
```

## Test Ownership

| Repo | Responsibility | Examples |
|------|---------------|----------|
| **VoxCore** | • Core functionality<br>• Plugin integration contract<br>• Mock plugin tests<br>• Performance baselines | `tests/integration/plugin_contract_test.sh`<br>`tests/mock_refiner_plugin.sh` |
| **VoxCompose** | • Unit tests (Java)<br>• CLI smoke tests<br>• Self-contained behavior tests<br>• **NO VoxCore dependency** | `src/test/java/...`<br>`tests/test_integration.sh` |
| **Future Plugins** | • Same as VoxCompose<br>• Self-contained<br>• No VoxCore dependency | Plugin-specific tests |

## Rationale

### 1. VoxCore Owns the Contract

VoxCore defines the plugin interface:
- `LLM_REFINER.CMD` - Command to execute
- `LLM_REFINER.ARGS` - Arguments to pass
- stdin/stdout protocol
- Duration metadata passing

**VoxCore should test that this contract works**, not individual plugins.

### 2. Plugins Are Independent

Each plugin:
- Has its own versioning
- Can be updated independently
- Should work standalone
- Shouldn't require VoxCore to run tests

**Plugins test their own behavior**, not integration.

### 3. Scalability

When adding more plugins:
- Each plugin doesn't duplicate VoxCore integration tests
- VoxCore tests the pattern once (with mock plugin)
- Plugins remain independently testable

## Implementation

### VoxCore Side

**Create plugin integration test:**

```bash
# tests/integration/plugin_contract_test.sh
#!/bin/bash
# Test that VoxCore correctly invokes plugins via the contract

# Test 1: Mock plugin receives stdin
echo "test input" | ./mock_refiner_plugin.sh | grep "received: test input"

# Test 2: Duration metadata passed correctly
echo "test" | ./mock_refiner_plugin.sh --duration 10 | grep "duration: 10"

# Test 3: Plugin output is captured
OUTPUT=$(echo "test" | ./mock_refiner_plugin.sh)
assert "$OUTPUT" == "refined: test"
```

**Create mock plugin:**

```bash
# tests/mock_refiner_plugin.sh
#!/bin/bash
# Mock plugin that verifies contract compliance

read INPUT
echo "refined: $INPUT"  # Simple passthrough for testing
```

**Optional: Real plugin test in CI (manual workflow):**

```yaml
# .github/workflows/install-test.yml
# Full-stack test (VoxCore + VoxCompose) - manual trigger only
```

### VoxCompose Side

**Current tests (already correct):**

- ✅ Unit tests: `src/test/java/...`
- ✅ Integration tests: `tests/test_integration.sh` (self-contained)
- ✅ CLI tests: stdin/stdout behavior
- ✅ No VoxCore dependency

**What VoxCompose should NOT do:**

- ❌ Require VoxCore installed to run tests
- ❌ Duplicate VoxCore integration tests
- ❌ Test VoxCore-specific behavior

## Testing Workflow

### Development

**VoxCore changes:**
```bash
cd ~/code/voxcore
make test  # Includes plugin contract test
```

**VoxCompose changes:**
```bash
cd ~/code/voxcompose
./tests/run_tests.sh  # Self-contained, no VoxCore needed
```

### CI/CD

**VoxCore CI:**
- ✅ Unit tests
- ✅ Plugin contract test (mock plugin)
- ✅ Performance baselines
- ⚠️ Full-stack test (manual only, not every PR)

**VoxCompose CI:**
- ✅ Unit tests
- ✅ CLI integration tests
- ✅ Self-contained behavior tests
- ❌ No VoxCore dependency

### Release Validation

**Before releasing VoxCore:**
```bash
# Test plugin contract still works
cd ~/code/voxcore
make test-plugin-contract

# Optional: Test with real VoxCompose (manual)
# Trigger install-test.yml workflow with full-stack mode
```

**Before releasing VoxCompose:**
```bash
# Test VoxCompose standalone
cd ~/code/voxcompose
./tests/run_tests.sh

# No need to test with VoxCore (VoxCore tests the contract)
```

## Version Alignment Issue

**Problem:** Recordings made with VoxCompose have mismatched versions.

**Solution:** Already implemented in `compare_versions.py`:
- Default: Exclude VoxCompose recordings (clean VoxCore metrics)
- Optional: `--include-voxcompose` for full-stack metrics
- Optional: `--voxcompose-version X.Y.Z` for specific version

**For plugin performance testing:**
- Create separate script: `compare_voxcompose_impact.py` (in VoxCompose repo)
- Measures VoxCompose improvements independently

## Best Practices

### ✅ DO

1. **Test plugin contract in VoxCore** - Verify the interface works
2. **Test plugin behavior in plugin repo** - Self-contained tests
3. **Use mock plugins for CI** - Fast, no external dependencies
4. **Document plugin contract** - Clear interface specification
5. **Keep plugins independent** - No circular dependencies

### ❌ DON'T

1. **Don't require VoxCore for plugin tests** - Plugins should be standalone
2. **Don't duplicate integration tests** - VoxCore tests the contract once
3. **Don't test plugin internals in VoxCore** - That's the plugin's job
4. **Don't couple plugin versions** - They version independently
5. **Don't make plugins depend on VoxCore** - Keep boundaries clear

## Future Plugins

This strategy scales to any number of plugins:

```
VoxCore (host)
├── Plugin contract tests (mock plugins)
└── Optional: Real plugin tests (manual CI)

Plugin 1 (VoxCompose)
├── Unit tests
└── Self-contained integration tests

Plugin 2 (Future)
├── Unit tests
└── Self-contained integration tests

Plugin N (Future)
├── Unit tests
└── Self-contained integration tests
```

Each plugin:
- Tests itself independently
- Doesn't require VoxCore
- Follows the same contract
- Can be developed/deployed separately

## Summary

**Test Location Decision:**

| Test Type | Location | Reason |
|-----------|----------|--------|
| Plugin unit tests | Plugin repo | Plugin owns its logic |
| Plugin CLI tests | Plugin repo | Plugin tests its interface |
| Plugin integration | Plugin repo | Self-contained behavior |
| **Plugin contract** | **VoxCore repo** | **VoxCore owns the contract** |
| Full-stack E2E | VoxCore repo (manual) | Validates real integration |

**Key Principle:** VoxCore tests the contract. Plugins test themselves.

