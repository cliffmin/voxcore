#!/bin/bash

# Sanitize test fixtures for public GitHub release
# This script creates minimal, professional test samples

set -euo pipefail

FIXTURES_DIR="tests/fixtures"
BACKUP_DIR="tests/fixtures_backup_$(date +%Y%m%d_%H%M%S)"

echo "=== Test Fixture Sanitization Script ==="
echo "This will replace existing test fixtures with sanitized samples"
echo ""

# Backup existing fixtures
if [ -d "$FIXTURES_DIR" ]; then
    echo "Backing up existing fixtures to $BACKUP_DIR..."
    cp -r "$FIXTURES_DIR" "$BACKUP_DIR"
    echo "Backup complete: $BACKUP_DIR"
fi

# Create new fixture structure
echo "Creating sanitized fixture structure..."
rm -rf "$FIXTURES_DIR"
mkdir -p "$FIXTURES_DIR/samples"

# Create sample text files with professional content
cat > "$FIXTURES_DIR/samples/sample1.txt" << 'EOF'
This is a test of the push-to-talk dictation system.
EOF

cat > "$FIXTURES_DIR/samples/sample2.txt" << 'EOF'
The quick brown fox jumps over the lazy dog. This sentence contains all letters of the alphabet.
EOF

cat > "$FIXTURES_DIR/samples/sample3.txt" << 'EOF'
Testing punctuation: Hello, world! How are you today? That's wonderful.

Testing numbers: The meeting is at 3:30 PM on December 15th, 2024.
EOF

# Create a README for the fixtures
cat > "$FIXTURES_DIR/README.md" << 'EOF'
# Test Fixtures

This directory contains minimal test samples for the push-to-talk dictation system.

## Structure

- `samples/` - Sample text files representing expected transcription outputs

## Note

Audio files are not included in the repository to keep size minimal. 
The test suite can generate synthetic audio or use system recordings as needed.

## Creating Test Audio

To create test audio files locally:
```bash
# Use macOS say command to generate test audio
say -o test.wav "This is a test of the push-to-talk dictation system"
```
EOF

echo ""
echo "=== Sanitization Complete ==="
echo ""
echo "Summary:"
echo "✓ Backed up original fixtures to: $BACKUP_DIR"
echo "✓ Created minimal text samples with professional content"
echo "✓ Removed audio files to reduce repository size"
echo "✓ Added README explaining fixture structure"
echo ""
echo "Total new fixture size:"
du -sh "$FIXTURES_DIR"
echo ""
echo "Next steps:"
echo "1. Review the new fixtures in $FIXTURES_DIR"
echo "2. Run 'git add $FIXTURES_DIR' to stage changes"
echo "3. Commit with: git commit -m 'chore: sanitize test fixtures for public release'"
echo ""
echo "To restore original fixtures:"
echo "  mv $BACKUP_DIR $FIXTURES_DIR"
