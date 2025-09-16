#!/bin/bash

# Test the Java post-processor with disfluency examples
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "Java Post-Processor Integration Test"
echo "========================================="

# Check if Java processor is built
JAR_PATH="$PROJECT_ROOT/whisper-post-processor/dist/whisper-post.jar"
if [[ ! -f "$JAR_PATH" ]]; then
    echo -e "${RED}Error: Java processor not built. Run 'make build-java' first.${NC}"
    exit 1
fi

# Test cases from disfluency_test.txt
echo -e "\n${YELLOW}Testing disfluency removal...${NC}"

# Read test cases
TEST_FILE="$PROJECT_ROOT/tests/fixtures/golden/disfluency_test.txt"
if [[ ! -f "$TEST_FILE" ]]; then
    echo -e "${RED}Error: Test file not found: $TEST_FILE${NC}"
    exit 1
fi

PASSED=0
FAILED=0

while IFS='|' read -r input expected; do
    # Skip comments and empty lines
    [[ "$input" =~ ^#.*$ ]] && continue
    [[ -z "$input" ]] && continue
    
    # Trim whitespace
    input=$(echo "$input" | xargs)
    expected=$(echo "$expected" | xargs)
    
    # Test the processor
    result=$(echo "$input" | java -jar "$JAR_PATH" 2>/dev/null | xargs)
    
    if [[ "$result" == "$expected" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: '$input' -> '$result'"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: '$input'"
        echo "  Expected: '$expected'"
        echo "  Got:      '$result'"
        ((FAILED++))
    fi
done < "$TEST_FILE"

echo -e "\n========================================="
echo "Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}"

# Test JSON processing
echo -e "\n${YELLOW}Testing JSON processing...${NC}"

JSON_INPUT='{"text":"um, this is, uh, a test.","segments":[{"text":"um, this is, uh, a test.","start":0.0,"end":2.5}]}'
EXPECTED_JSON_TEXT="This is, a test."

# Test JSON mode
JSON_RESULT=$(echo "$JSON_INPUT" | java -jar "$JAR_PATH" --json 2>/dev/null | jq -r '.text' 2>/dev/null || echo "JSON parse error")

if [[ "$JSON_RESULT" == "$EXPECTED_JSON_TEXT" ]]; then
    echo -e "${GREEN}✓ PASS${NC}: JSON processing works"
else
    echo -e "${RED}✗ FAIL${NC}: JSON processing"
    echo "  Expected text: '$EXPECTED_JSON_TEXT'"
    echo "  Got:           '$JSON_RESULT'"
fi

# Test with real Whisper output simulation
echo -e "\n${YELLOW}Testing with simulated Whisper output...${NC}"

WHISPER_SIM=$(cat << 'EOF'
{
  "text": " Um, so basically, you know, I think we should, uh, probably implement the new feature. It's kind of important, I mean, for the project.",
  "segments": [
    {
      "text": " Um, so basically, you know,",
      "start": 0.0,
      "end": 2.5
    },
    {
      "text": " I think we should, uh, probably",
      "start": 2.5,
      "end": 4.8
    },
    {
      "text": " implement the new feature.",
      "start": 4.8,
      "end": 6.2
    },
    {
      "text": " It's kind of important, I mean,",
      "start": 6.2,
      "end": 8.1
    },
    {
      "text": " for the project.",
      "start": 8.1,
      "end": 9.0
    }
  ]
}
EOF
)

PROCESSED=$(echo "$WHISPER_SIM" | java -jar "$JAR_PATH" --json 2>/dev/null)
PROCESSED_TEXT=$(echo "$PROCESSED" | jq -r '.text' 2>/dev/null || echo "Error")

echo "Original: Um, so basically, you know, I think we should, uh, probably implement the new feature."
echo "Processed: $PROCESSED_TEXT"

# Performance test
echo -e "\n${YELLOW}Performance test...${NC}"

# Create a large input file
LARGE_INPUT=$(for i in {1..100}; do echo "Um, this is, uh, test number $i, you know."; done)

START_TIME=$(date +%s%N)
echo "$LARGE_INPUT" | java -jar "$JAR_PATH" > /dev/null 2>&1
END_TIME=$(date +%s%N)

ELAPSED=$((($END_TIME - $START_TIME) / 1000000))
echo "Processed 100 lines in ${ELAPSED}ms"

if [[ $ELAPSED -lt 1000 ]]; then
    echo -e "${GREEN}✓ Performance acceptable (<1s for 100 lines)${NC}"
else
    echo -e "${YELLOW}⚠ Performance could be improved (>1s for 100 lines)${NC}"
fi

# Exit with appropriate code
if [[ $FAILED -gt 0 ]]; then
    exit 1
else
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
fi