#!/bin/bash
# Mock plugin for testing VoxCore's plugin integration contract
# Simulates a plugin that receives stdin and returns refined output

# Use less strict error handling for CI compatibility
set -e

# Parse arguments
DURATION=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --duration)
            DURATION="$2"
            shift 2
            ;;
        --capabilities)
            # Return capabilities JSON
            echo '{"activation":{"long_form":{"min_duration":21,"optimal_duration":30}}}'
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# Read input from stdin (handle empty input gracefully)
INPUT=$(cat || echo "")

# Simple mock refinement: prefix with "refined: "
# In real plugins, this would do actual processing
if [[ -n "$DURATION" ]]; then
    echo "refined: $INPUT (duration: ${DURATION}s)"
else
    echo "refined: $INPUT"
fi

