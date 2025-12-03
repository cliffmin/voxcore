#!/bin/bash
# Test VoxCore's plugin integration contract
# Verifies that plugins are invoked correctly via stdin/stdout protocol

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MOCK_PLUGIN="$SCRIPT_DIR/mock_refiner_plugin.sh"

if [[ ! -f "$MOCK_PLUGIN" ]]; then
    echo "Error: Mock plugin not found: $MOCK_PLUGIN" >&2
    exit 1
fi

echo "=== Plugin Contract Test ==="
echo ""

FAILED=0

# Test 1: Basic stdin/stdout
echo "Test 1: Basic stdin/stdout protocol"
INPUT="test input"
OUTPUT=$(echo "$INPUT" | bash "$MOCK_PLUGIN")
if echo "$OUTPUT" | grep -q "refined: $INPUT"; then
    echo "✅ PASS - Plugin receives stdin and returns stdout"
else
    echo "❌ FAIL - Expected 'refined: $INPUT', got '$OUTPUT'"
    FAILED=1
fi

# Test 2: Duration argument
echo ""
echo "Test 2: Duration metadata passing"
OUTPUT=$(echo "test" | bash "$MOCK_PLUGIN" --duration 10)
if echo "$OUTPUT" | grep -q "duration: 10s"; then
    echo "✅ PASS - Duration argument passed correctly"
else
    echo "❌ FAIL - Duration not passed correctly, got '$OUTPUT'"
    FAILED=1
fi

# Test 3: Capabilities endpoint
echo ""
echo "Test 3: Capabilities negotiation"
CAPS=$(bash "$MOCK_PLUGIN" --capabilities)
if echo "$CAPS" | jq -e '.activation.long_form.min_duration' >/dev/null 2>&1; then
    echo "✅ PASS - Capabilities endpoint returns valid JSON"
else
    echo "❌ FAIL - Invalid capabilities response: $CAPS"
    FAILED=1
fi

# Test 4: Empty input handling
echo ""
echo "Test 4: Edge case - empty input"
OUTPUT=$(echo "" | bash "$MOCK_PLUGIN")
if [[ -n "$OUTPUT" ]]; then
    echo "✅ PASS - Empty input handled (got: '$OUTPUT')"
else
    echo "⚠️  WARN - Empty input produced no output (may be acceptable)"
fi

# Test 5: Multi-line input
echo ""
echo "Test 5: Multi-line input handling"
MULTILINE="line one
line two"
OUTPUT=$(echo "$MULTILINE" | bash "$MOCK_PLUGIN")
if echo "$OUTPUT" | grep -q "line one" && echo "$OUTPUT" | grep -q "line two"; then
    echo "✅ PASS - Multi-line input handled correctly"
else
    echo "❌ FAIL - Multi-line input not handled correctly"
    FAILED=1
fi

echo ""
if [[ $FAILED -eq 0 ]]; then
    echo "=== All Plugin Contract Tests Passed ==="
    exit 0
else
    echo "=== Some Tests Failed ==="
    exit 1
fi

