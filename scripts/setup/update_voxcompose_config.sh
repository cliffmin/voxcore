#!/bin/bash
# Update VoxCompose configuration for proper Ollama integration

set -e

echo "=== Updating VoxCompose Configuration for Ollama Integration ==="
echo ""

# Check if VoxCompose is installed
if ! command -v voxcompose &> /dev/null; then
    echo "❌ VoxCompose not found. Install with: brew install voxcompose"
    exit 1
fi

echo "✅ VoxCompose found at: $(which voxcompose)"

# Check if Ollama is running
echo ""
echo "Checking Ollama status..."
if curl -s -m 2 http://127.0.0.1:11434/api/tags > /dev/null 2>&1; then
    echo "✅ Ollama is running"
    
    # Check for models
    if docker exec ollama ollama list 2>/dev/null | grep -q "llama3.2:1b"; then
        echo "✅ llama3.2:1b model is available"
    else
        echo "⚠️  llama3.2:1b model not found"
        echo "Installing lightweight model..."
        docker exec ollama ollama pull llama3.2:1b
    fi
else
    echo "⚠️  Ollama not running"
    echo ""
    echo "To start Ollama:"
    echo "  docker start ollama"
    echo "Or install fresh:"
    echo "  docker run -d --name ollama --restart unless-stopped \\"
    echo "    -p 11434:11434 -v ollama:/root/.ollama ollama/ollama"
fi

# Create wrapper script with proper timeout
WRAPPER_PATH="$HOME/.local/bin/voxcompose-ptt"
mkdir -p "$(dirname "$WRAPPER_PATH")"

cat > "$WRAPPER_PATH" << 'EOF'
#!/bin/bash
# VoxCompose wrapper for PTT with proper timeout and model

# Set default timeout for LLM operations (30 seconds)
TIMEOUT_MS="${VOX_TIMEOUT_MS:-30000}"

# Set default model (lightweight 1.3GB model)
MODEL="${VOX_MODEL:-llama3.2:1b}"

# Check input duration if provided
DURATION="$1"
if [[ "$1" == "--duration" ]] && [[ -n "$2" ]]; then
    DURATION="$2"
    shift 2
fi

# Determine if we should use LLM refinement
USE_LLM=true
if [[ -n "$DURATION" ]] && [[ "$DURATION" -lt 21 ]]; then
    # Short recording - skip LLM
    USE_LLM=false
fi

# Check if Ollama is available
if $USE_LLM && ! curl -s -m 1 http://127.0.0.1:11434/api/tags > /dev/null 2>&1; then
    echo "INFO: Ollama not available, using corrections only" >&2
    USE_LLM=false
fi

if $USE_LLM; then
    # Run with LLM refinement
    exec voxcompose --model "$MODEL" --timeout-ms "$TIMEOUT_MS" "$@"
else
    # Run without LLM (corrections only)
    VOX_REFINE=0 exec voxcompose "$@"
fi
EOF

chmod +x "$WRAPPER_PATH"
echo ""
echo "✅ Created wrapper script at: $WRAPPER_PATH"

# Update PTT config to use the wrapper
PTT_CONFIG="$HOME/.config/hammerspoon/ptt_config.lua"
if [[ ! -f "$PTT_CONFIG" ]]; then
    PTT_CONFIG="$HOME/.hammerspoon/ptt_config.lua"
fi

if [[ -f "$PTT_CONFIG" ]]; then
    echo ""
    echo "📝 Add this to your $PTT_CONFIG:"
    echo ""
    cat << 'EOF'
-- LLM Refiner Configuration (VoxCompose with Ollama)
LLM_REFINER = {
  ENABLED = true,
  CMD = {"$HOME/.local/bin/voxcompose-ptt"},
  ARGS = {"--timeout-ms", "30000"},
  -- Threshold: use for recordings > 21 seconds
  MIN_DURATION_SECONDS = 21,
  -- Model selection (lightweight for speed)
  MODEL = "llama3.2:1b"
}
EOF
else
    echo "⚠️  PTT config not found at expected locations"
fi

# Test the setup
echo ""
echo "Testing VoxCompose integration..."
TEST_RESULT=$(echo "quick test" | "$WRAPPER_PATH" 2>/dev/null | head -c 50)
if [[ -n "$TEST_RESULT" ]]; then
    echo "✅ VoxCompose is working"
else
    echo "⚠️  VoxCompose test failed"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Ensure Ollama is running: docker start ollama"
echo "2. Update your PTT config with the LLM_REFINER settings above"
echo "3. Reload Hammerspoon config"
echo ""
echo "The system will automatically:"
echo "- Use VoxCompose + Ollama for recordings > 21 seconds"
echo "- Fall back to corrections-only if Ollama is unavailable"
echo "- Use standard processing for short recordings < 21 seconds"