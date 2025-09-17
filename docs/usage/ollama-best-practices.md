# Ollama/LLM Best Practices for Long Recordings

## Overview

When users record audio clips longer than 21 seconds, the system can use VoxCompose with Ollama for AI-powered refinement. This guide covers best practices for handling scenarios where Ollama might not be available.

## The 21-Second Threshold

- **< 21 seconds**: Standard Whisper processing with basic corrections
- **> 21 seconds**: VoxCompose with optional LLM refinement via Ollama

## Best Practices Implementation

### 1. **Graceful Degradation** (Recommended)

The system should automatically fall back to basic processing when Ollama isn't available:

```lua
-- Priority order:
1. VoxCompose + Ollama (best quality)
2. VoxCompose without LLM (good quality, faster)
3. Standard Whisper (basic quality, fastest)
```

### 2. **User Experience Flow**

#### Automatic Fallback (Default)
When Ollama is unavailable, the system:
1. Checks if Ollama is running (cached for 60 seconds)
2. If not available, uses VoxCompose without LLM
3. Shows subtle notification about degraded mode
4. Continues processing without interruption

#### Interactive Mode (Optional)
For power users who want control:
1. Detect Ollama unavailability
2. Present options via Hammerspoon chooser:
   - "Start Ollama and use AI refinement"
   - "Use basic corrections only (faster)"
   - "Use standard processing"
3. Remember user preference for session

### 3. **Smart Ollama Management**

The `ollama_handler.lua` module provides:

- **Health Checks**: Lightweight checks with 2-second timeout
- **Caching**: Results cached for 60 seconds to avoid repeated checks
- **Auto-start**: Attempts to start Ollama container if Docker is running
- **Status Monitoring**: Periodic checks with user notifications
- **OrbStack Support**: Detects and works with OrbStack containers

### 4. **Configuration Options**

Users can configure behavior in `ptt_config.lua`:

```lua
-- Ollama/LLM Configuration
ollama = {
    enabled = true,                    -- Use Ollama when available
    auto_start = true,                 -- Try to start if not running
    show_prompts = false,              -- Show chooser (false = auto-fallback)
    fallback_to_voxcompose = true,    -- Use VoxCompose without LLM as fallback
    check_interval = 60,               -- Seconds between status checks
    notification_on_change = true      -- Notify when Ollama status changes
}
```

### 5. **Performance Considerations**

| Scenario | Processing Time | Quality |
|----------|----------------|---------|
| VoxCompose + Ollama | 3-5 seconds | Excellent - Full refinement |
| VoxCompose only | 1-2 seconds | Good - Corrections only |
| Standard Whisper | < 1 second | Basic - No corrections |

### 6. **Setup Instructions for Users**

#### Quick Setup (Docker)
```bash
# Install Docker Desktop or OrbStack
brew install --cask orbstack

# Run Ollama container
docker run -d \
  --name ollama \
  --restart unless-stopped \
  -p 11434:11434 \
  -v ollama:/root/.ollama \
  ollama/ollama

# Pull lightweight model
docker exec ollama ollama pull llama3.2:1b
```

#### Verification
```bash
# Check if Ollama is running
curl http://localhost:11434/api/tags

# Test with VoxCompose
echo "test text" | voxcompose
```

## Implementation Status

### Current Implementation
- ✅ Ollama container management via Docker/OrbStack
- ✅ Health check with timeout
- ✅ Graceful fallback to VoxCompose without LLM
- ✅ Status caching to reduce overhead
- ⚠️ User notification system (needs integration)
- ⚠️ Auto-start functionality (needs testing)

### Recommended Defaults

For best user experience:
1. **Silent fallback**: Don't interrupt workflow
2. **Status bar indicator**: Show LLM status in menu bar
3. **First-run setup**: Offer to install Ollama on first long recording
4. **Background monitoring**: Check status periodically

## Error Scenarios

### Scenario 1: Ollama Not Installed
- **Detection**: Port 11434 not responding
- **Action**: Use VoxCompose basic mode
- **User Feedback**: One-time notification with setup link

### Scenario 2: Ollama Crashed
- **Detection**: Was working, now not responding
- **Action**: Attempt auto-restart once
- **User Feedback**: Brief notification if restart fails

### Scenario 3: Model Not Downloaded
- **Detection**: Ollama running but model missing
- **Action**: Auto-download small model (1.3GB)
- **User Feedback**: Progress notification

### Scenario 4: Slow Response
- **Detection**: Response time > 10 seconds
- **Action**: Cancel and fallback to basic mode
- **User Feedback**: "Using fast mode" notification

## Testing

Test the fallback behavior:

```bash
# Stop Ollama
docker stop ollama

# Record long audio (should fallback gracefully)
# The system should use VoxCompose without LLM

# Start Ollama
docker start ollama

# Record again (should use LLM refinement)
```

## Future Enhancements

1. **Local LLM Options**: Support for native macOS LLMs (MLX, Core ML)
2. **Model Selection**: Let users choose between speed/quality tradeoffs
3. **Async Processing**: Process in background, notify when ready
4. **Cloud Fallback**: Optional cloud API when local unavailable
5. **Learning Mode**: Cache common refinements for offline use