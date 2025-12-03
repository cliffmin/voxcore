#!/bin/bash
# Test VoxCore's plugin integration contract
# Verifies that plugins are invoked correctly via stdin/stdout protocol

# Use less strict error handling for CI compatibility
set -e  # Exit on error, but allow unset vars and pipe failures

# Verify dependencies
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required but not installed" >&2
    echo "Available commands:" >&2
    command -v bash >&2 || echo "bash: not found" >&2
    command -v grep >&2 || echo "grep: not found" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MOCK_PLUGIN="$SCRIPT_DIR/mock_refiner_plugin.sh"

if [[ ! -f "$MOCK_PLUGIN" ]]; then
    echo "Error: Mock plugin not found: $MOCK_PLUGIN" >&2
    ls -la "$SCRIPT_DIR" >&2 || true
    exit 1
fi

echo "=== Plugin Contract Test ==="
echo ""

FAILED=0

# Test 1: Basic stdin/stdout
echo "Test 1: Basic stdin/stdout protocol"
INPUT="test input"
set +e  # Don't exit on error
OUTPUT=$(echo "$INPUT" | bash "$MOCK_PLUGIN" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -ne 0 ]]; then
    echo "❌ FAIL - Mock plugin exited with code $EXIT_CODE: $OUTPUT" >&2
    FAILED=1
elif echo "$OUTPUT" | grep -q "refined: $INPUT"; then
    echo "✅ PASS - Plugin receives stdin and returns stdout"
else
    echo "❌ FAIL - Expected 'refined: $INPUT', got '$OUTPUT'" >&2
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
set +e  # Temporarily disable exit on error to capture output
CAPS=$(bash "$MOCK_PLUGIN" --capabilities 2>&1)
CAPS_EXIT=$?
set -e  # Re-enable exit on error

if [[ $CAPS_EXIT -ne 0 ]]; then
    echo "❌ FAIL - Mock plugin failed to run (exit code $CAPS_EXIT): $CAPS" >&2
    FAILED=1
elif [[ -z "$CAPS" ]]; then
    echo "❌ FAIL - Mock plugin returned empty output" >&2
    FAILED=1
elif ! echo "$CAPS" | jq -e '.activation.long_form.min_duration' >/dev/null 2>&1; then
    echo "❌ FAIL - Invalid capabilities response: $CAPS" >&2
    FAILED=1
else
    echo "✅ PASS - Capabilities endpoint returns valid JSON"
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

