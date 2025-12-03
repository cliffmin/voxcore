# VoxCompose Testing & Version Alignment Issue

## Problem Statement

**Current Situation:**
- Recordings are made with **both** VoxCore and VoxCompose versions tracked in `.version` files
- VoxCompose versions **don't align** with VoxCore versions (independent versioning)
- All tests currently **only filter by VoxCore version**
- This means VoxCore 0.4.3 recordings might include:
  - Some with VoxCompose 1.0.0
  - Some with VoxCompose 1.1.0
  - Some with VoxCompose disabled

**Impact:**
- **Accuracy metrics are skewed** - Different VoxCompose versions produce different refinements
- **Performance metrics are skewed** - VoxCompose adds processing time
- **Can't isolate VoxCore improvements** - Changes might be masked by VoxCompose version differences
- **No VoxCompose-specific tests** - Can't measure VoxCompose performance gains

## Current State

### What's Tracked
- `.version` files contain:
  ```
  voxcore=0.4.3
  voxcompose=1.0.0
  model=base.en
  timestamp=2025-11-15T19:30:00Z
  ```

### What's NOT Filtered
- `compare_versions.py` - Only filters by VoxCore version
- `real_accuracy.py` - Doesn't check VoxCompose version
- Performance baselines - Don't separate VoxCompose vs VoxCore-only

### What's Missing
- No way to filter recordings by VoxCompose version
- No way to exclude VoxCompose-enabled recordings for VoxCore tests
- No VoxCompose-specific performance/accuracy tests

## Solutions

### Option 1: Filter Out VoxCompose Recordings (Recommended for VoxCore Tests)

**For VoxCore-only tests, exclude recordings made with VoxCompose:**

```python
# In compare_versions.py
def load_version_recordings(base_dir: Path, version: str, exclude_voxcompose: bool = True) -> List[Dict[str, Any]]:
    """Load recordings, optionally excluding those made with VoxCompose."""
    recordings = []
    for session_dir in version_dir.iterdir():
        # ... load metadata ...
        
        # Skip if VoxCompose was enabled
        if exclude_voxcompose and metadata.get('voxcompose') not in ('unknown', '', None):
            continue
            
        recordings.append(metadata)
    return recordings
```

**Pros:**
- Clean VoxCore metrics (no plugin interference)
- Simple to implement
- Matches goal of testing VoxCore in isolation

**Cons:**
- Loses data if most recordings use VoxCompose
- Can't measure VoxCompose impact

### Option 2: Filter by Both Versions

**Filter by VoxCore + VoxCompose version combination:**

```python
# Compare specific version combinations
python compare_versions.py \
  --voxcore 0.4.3 \
  --voxcompose 1.0.0 \
  --metrics accuracy
```

**Pros:**
- Most accurate comparison
- Can isolate both VoxCore and VoxCompose changes
- Full traceability

**Cons:**
- More complex
- Requires more data (need recordings for each combo)
- Harder to interpret results

### Option 3: Separate Test Suites

**Create separate test workflows:**
- `compare_voxcore_only.py` - Excludes VoxCompose recordings
- `compare_voxcompose_impact.py` - Compares VoxCore vs VoxCore+VoxCompose

**Pros:**
- Clear separation of concerns
- Can measure VoxCompose impact explicitly
- Best for understanding plugin value

**Cons:**
- More maintenance
- Need to run multiple test suites

## Recommended Approach

**Hybrid: Option 1 + Option 3**

1. **Default behavior**: Exclude VoxCompose recordings for VoxCore tests
   - Clean VoxCore metrics
   - Prevents version mismatch issues

2. **Optional flag**: `--include-voxcompose` to include them
   - For measuring full-stack performance

3. **Separate script**: `compare_voxcompose_impact.py`
   - Explicitly measures VoxCompose improvements
   - Compares VoxCore-only vs VoxCore+VoxCompose

## Implementation Plan

1. ✅ Update `compare_versions.py` to filter by VoxCompose version
2. ✅ Add `--exclude-voxcompose` flag (default: true)
3. ✅ Create `compare_voxcompose_impact.py` for plugin testing
4. ✅ Update documentation

## Testing Strategy

### VoxCore Tests (Default)
```bash
# Test VoxCore in isolation (excludes VoxCompose recordings)
python compare_versions.py --versions 0.4.3 0.5.0
```

### Full-Stack Tests (Optional)
```bash
# Include VoxCompose recordings
python compare_versions.py --versions 0.4.3 0.5.0 --include-voxcompose
```

### VoxCompose Impact Tests
```bash
# Measure VoxCompose improvements
python compare_voxcompose_impact.py --voxcore 0.4.3 --voxcompose 1.0.0 1.1.0
```

## Notes

- **Golden tests are unaffected** - They're synthetic, no VoxCompose involved
- **Real recordings need filtering** - Most likely made with VoxCompose
- **Performance baselines** - Should exclude VoxCompose for fair comparison
- **Accuracy baselines** - Should exclude VoxCompose to measure VoxCore improvements

