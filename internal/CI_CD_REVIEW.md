# CI/CD Review & Improvements

## Current State

### ✅ What's Good
1. **Java tests** - Unit tests run on every PR
2. **Validation** - Lua syntax, shellcheck, docs check
3. **Release automation** - Auto-creates GitHub releases on tags
4. **Manual install test** - Exists but manual-only (`install-test.yml`)

### ⚠️ What's Missing
1. **No automatic install test** - Only manual workflow_dispatch
2. **No upgrade test** - Can't verify upgrades work
3. **No macOS testing** - All tests run on Ubuntu (but VoxCore is macOS-only)
4. **No integration with main CI** - Install tests are separate

## Improvements Made

### 1. New Workflow: `install-upgrade-test.yml`
- **Install test**: Runs on every PR to main
  - Fresh install from Homebrew
  - Verifies binaries, symlinks, config creation
  - Tests `voxcore-install` script
  
- **Upgrade test**: Runs on main branch pushes
  - Installs previous version
  - Upgrades to current version
  - Verifies config preservation
  - Verifies binaries still work

### 2. Updated `ci.yml`
- Added note about install/upgrade tests in status check

## Recommendations

### High Priority
1. ✅ **Add install test** - DONE (new workflow)
2. ✅ **Add upgrade test** - DONE (new workflow)
3. **Consider**: Make install test required for PRs (add to branch protection)

### Medium Priority
1. **Performance baseline in CI** - Run `compare_performance_baseline.sh` on PRs
2. **Golden accuracy in CI** - Run `compare_golden_accuracy.sh` on PRs
3. **Matrix testing** - Test on multiple macOS versions (macos-13, macos-14)

### Low Priority
1. **Cache Homebrew** - Speed up install tests
2. **Parallel jobs** - Run install/upgrade in parallel
3. **Notification** - Alert on CI failures

## Workflow Triggers

**Install test runs:**
- On PRs to main
- On pushes to main
- On version tags
- Manual trigger

**Upgrade test runs:**
- Only on pushes to main (needs previous version)
- Manual trigger

## Testing Strategy

```
PR → main
├── Java tests (Ubuntu) ✅
├── Validation (Ubuntu) ✅
└── Install test (macOS) ✅ NEW

main push
├── All above +
└── Upgrade test (macOS) ✅ NEW
```

## Next Steps

1. **Test the new workflow** - Push to a test branch
2. **Add to branch protection** - Make install test required
3. **Monitor CI times** - Install tests add ~15min (macOS runners are slower)

## Notes

- Install tests require macOS runners (more expensive, slower)
- Upgrade test only works if previous version exists in Homebrew tap
- Consider making install test optional for draft PRs (save CI minutes)

