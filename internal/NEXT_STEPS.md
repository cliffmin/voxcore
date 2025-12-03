# Next Steps & Recommendations

## Immediate Actions

### 1. Test the New CI Workflows
```bash
# Push branch and verify workflows run
git push origin golden-test-improvements

# Check GitHub Actions:
# - Install test should run on PR
# - Upgrade test will run when merged to main
```

### 2. Verify Plugin Contract Tests
```bash
# Run locally to ensure they pass
bash tests/integration/plugin_contract_test.sh

# Add to CI (recommended):
# Add to .github/workflows/ci.yml validation job
```

### 3. Test Version Filtering
```bash
# Test VoxCompose filtering works
python scripts/analysis/compare_versions.py \
  --versions 0.4.3 0.5.0 \
  --exclude-voxcompose  # Default behavior

python scripts/analysis/compare_versions.py \
  --versions 0.4.3 0.5.0 \
  --include-voxcompose  # Include all
```

## Recommended Additions

### 1. Add Plugin Contract Test to CI
**File:** `.github/workflows/ci.yml`

Add to `validation` job:
```yaml
- name: Test plugin contract
  run: |
    bash tests/integration/plugin_contract_test.sh
```

**Why:** Ensures plugin contract doesn't break

### 2. Add Performance Baseline to CI (Optional)
**File:** `.github/workflows/ci.yml`

Add to `validation` job (non-blocking):
```yaml
- name: Check performance baseline
  continue-on-error: true
  run: |
    ./scripts/metrics/compare_performance_baseline.sh || echo "Performance check skipped"
```

**Why:** Catches performance regressions early

### 3. Add Golden Accuracy to CI (Optional)
**File:** `.github/workflows/ci.yml`

Add to `validation` job (non-blocking):
```yaml
- name: Check golden accuracy
  continue-on-error: true
  run: |
    ./scripts/metrics/compare_golden_accuracy.sh || echo "Accuracy check skipped"
```

**Why:** Catches accuracy regressions early

### 4. Create VoxCompose Impact Script (Future)
**Location:** `~/code/voxcompose/scripts/analysis/compare_voxcompose_impact.py`

**Purpose:** Measure VoxCompose improvements independently

**Why:** Separates plugin performance from core performance

## Documentation Updates

### 1. Update CHANGELOG.md
Add entry under `[Unreleased]`:
```markdown
### Added
- Golden test audio fixtures for accuracy testing
- CI/CD install and upgrade test workflows
- Plugin contract tests and mock plugin
- Performance baseline establishment and comparison
- VoxCompose version filtering for analysis scripts
```

### 2. Update README.md (Optional)
Add testing section if missing:
```markdown
## Testing

VoxCore includes comprehensive tests:
- Unit tests (Java)
- Integration tests (plugin contract)
- Golden accuracy tests
- Performance baseline tests

See [tests/README.md](tests/README.md) for details.
```

## Branch Protection (Recommended)

### Add Required Checks
1. **Install test** - Ensures installation works
2. **Plugin contract test** - Ensures plugin interface works
3. **Java tests** - Core functionality

### Optional Checks (Non-blocking)
1. **Performance baseline** - Warns on regressions
2. **Golden accuracy** - Warns on accuracy drops

## Future Enhancements

### 1. Plugin Marketplace Documentation
- Document plugin API contract
- Create plugin template
- Add plugin examples

### 2. Performance Monitoring
- Track performance over time
- Alert on significant regressions
- Dashboard for metrics

### 3. Test Coverage
- Add golden accuracy to CI
- Add performance baseline to CI
- Add plugin contract to required checks

## Questions to Consider

1. **Should install test be required?** (Recommended: Yes)
2. **Should plugin contract test be required?** (Recommended: Yes)
3. **Should performance/accuracy checks block PRs?** (Recommended: No, warnings only)
4. **Should we add VoxCompose impact script?** (Recommended: Yes, in VoxCompose repo)

## Summary

✅ **Done:**
- Golden test fixtures
- CI/CD install/upgrade tests
- Plugin contract tests
- Performance baseline scripts
- VoxCompose version filtering
- Documentation

⏭️ **Next:**
- Add plugin contract test to CI
- Test workflows on PR
- Update CHANGELOG
- Consider adding performance/accuracy checks (non-blocking)

🎯 **Future:**
- Plugin marketplace docs
- Performance monitoring dashboard
- VoxCompose impact measurement script

