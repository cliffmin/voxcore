#!/bin/bash

# Run all tests and generate accuracy report

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "🧪 Running Java Post-Processor Tests"
echo "===================================="
echo ""

# Build if needed
if [ ! -f "build/libs/whisper-post.jar" ]; then
    echo "Building project..."
    gradle build --no-daemon -q
fi

# Run unit tests
echo "📋 Unit Tests"
echo "-------------"
gradle test --no-daemon 2>&1 | grep -E "(test|PASSED|FAILED|SUCCESS)" || true

echo ""
echo "📊 Accuracy Tests"
echo "-----------------"
gradle test --tests AccuracyTest --info 2>&1 | grep -E "(✅|❌|ACCURACY|WER|Average)" || true

echo ""
echo "⚡ Performance Tests"
echo "--------------------"
gradle test --tests "*Performance*" --info 2>&1 | grep -E "(processing time|Throughput)" || true

# Generate test report
echo ""
echo "📝 Generating HTML Report..."
gradle test jacocoTestReport --no-daemon -q

# Check if tests passed
if gradle test --no-daemon -q; then
    echo -e "\n${GREEN}✅ All tests passed!${NC}"
    RESULT=0
else
    echo -e "\n${RED}❌ Some tests failed${NC}"
    RESULT=1
fi

# Show coverage if available
if [ -f "build/reports/jacoco/test/html/index.html" ]; then
    echo ""
    echo "📈 Coverage Report: build/reports/jacoco/test/html/index.html"
fi

# Show test report location
echo "📄 Test Report: build/reports/tests/test/index.html"
echo ""

# Generate accuracy summary
echo "=== ACCURACY SUMMARY ==="
cat > accuracy-report.md << 'EOF'
# Post-Processor Accuracy Report

## Test Coverage
- ✅ Unit tests for each processor
- ✅ Integration tests for full pipeline
- ✅ Golden dataset validation
- ✅ Performance benchmarks

## Metrics
- **Accuracy**: Tests against golden dataset
- **WER (Word Error Rate)**: Measures word-level differences
- **Performance**: Processing time and throughput

## Test Categories
1. **Merged Words**: Fixing common word mergers from Whisper
2. **Sentence Boundaries**: Detecting and fixing run-on sentences
3. **Capitalization**: Proper case for sentences and "I"
4. **Punctuation**: Normalizing spacing
5. **Complex**: Multiple issues in single input
6. **Preserve**: Ensuring correct text isn't modified

## How to Run
```bash
# Run all tests
./run-tests.sh

# Run specific test
gradle test --tests MergedWordProcessorTest

# Run with coverage
gradle test jacocoTestReport
```

## Integration with CI
Tests run automatically on:
- Every commit
- Pull requests
- Before releases
EOF

echo "Report saved to: accuracy-report.md"
echo ""

exit $RESULT
