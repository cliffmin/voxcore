#!/bin/bash

# Organize test data into personal (private) and golden (public) fixtures

set -euo pipefail

echo "=== Organizing Test Data ==="
echo ""

FIXTURES_DIR="tests/fixtures"
PERSONAL_DIR="$FIXTURES_DIR/personal"
GOLDEN_DIR="$FIXTURES_DIR/golden"

# Create directories
mkdir -p "$PERSONAL_DIR"
mkdir -p "$GOLDEN_DIR"

# Move existing personal recordings
if [ -d "$FIXTURES_DIR/samples" ] || [ -d "$FIXTURES_DIR/samples_current" ]; then
    echo "Moving personal recordings to $PERSONAL_DIR..."
    
    # Move samples directories
    for dir in samples samples_current batches baselines; do
        if [ -d "$FIXTURES_DIR/$dir" ]; then
            echo "  Moving $dir..."
            mv "$FIXTURES_DIR/$dir" "$PERSONAL_DIR/" 2>/dev/null || true
        fi
    done
fi

# Create .gitignore for personal data
cat > "$PERSONAL_DIR/.gitignore" << 'EOF'
# Personal voice recordings - not for public distribution
*
!.gitignore
!README.md
EOF

# Create README for personal data
cat > "$PERSONAL_DIR/README.md" << 'EOF'
# Personal Test Data

This directory contains personal voice recordings used for testing.
These files are excluded from git and should not be shared publicly.

## Structure

- `samples/` - Individual test recordings
- `samples_current/` - Latest test batch
- `baselines/` - Baseline recordings for comparison
- `batches/` - Organized test batches

## Usage

These recordings are used for:
- Personal accuracy testing
- Regression testing with your specific voice
- Performance benchmarking

To run tests against personal data:
```bash
bash scripts/test_personal.sh
```
EOF

# Update main .gitignore
if ! grep -q "tests/fixtures/personal/" .gitignore 2>/dev/null; then
    echo "" >> .gitignore
    echo "# Personal test data (not for distribution)" >> .gitignore
    echo "tests/fixtures/personal/" >> .gitignore
    echo "tests/results/" >> .gitignore
fi

echo ""
echo "=== Data Organization Complete ==="
echo ""
echo "Structure:"
echo "  tests/fixtures/"
echo "    ├── golden/        # Public synthetic test data (will be in git)"
echo "    │   ├── micro/"
echo "    │   ├── short/"
echo "    │   ├── medium/"
echo "    │   └── long/"
echo "    └── personal/      # Your voice recordings (gitignored)"
echo "        ├── samples/"
echo "        └── baselines/"
echo ""
echo "Next steps:"
echo "1. Generate golden dataset: bash scripts/generate_golden_dataset.sh"
echo "2. Test accuracy: bash scripts/test_accuracy.sh"
echo "3. Your personal data is safe in: $PERSONAL_DIR"
