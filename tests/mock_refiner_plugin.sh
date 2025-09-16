#!/bin/bash
# Mock refiner plugin for testing capability negotiation

if [ "$1" = "--capabilities" ]; then
    cat <<EOF
{
  "version": "1.0",
  "activation": {
    "long_form": {
      "min_duration": 15,
      "description": "Test threshold of 15 seconds"
    }
  },
  "preferences": {
    "whisper_model": "base.en"
  }
}
EOF
    exit 0
fi

# Normal refiner behavior (just echo with prefix)
input=$(cat)
echo "[REFINED] $input"