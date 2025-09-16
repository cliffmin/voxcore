#!/bin/bash
# Debug script to test recording pipeline

echo "=== Push-to-Talk Debug Test ==="
echo ""

# Test 1: Check ffmpeg recording
echo "1. Testing ffmpeg recording (3 seconds)..."
TEST_WAV="/tmp/test_recording.wav"
/opt/homebrew/bin/ffmpeg -y -f avfoundation -t 3 -i ":1" -ac 1 -ar 16000 -sample_fmt s16 "$TEST_WAV" 2>/dev/null

if [ -f "$TEST_WAV" ]; then
    SIZE=$(stat -f%z "$TEST_WAV")
    echo "   ✓ Recording created: $SIZE bytes"
    
    # Test 2: Check whisper transcription
    echo ""
    echo "2. Testing whisper transcription..."
    ~/.local/bin/whisper "$TEST_WAV" --model base.en --language en --device cpu --output_format json --output_dir /tmp 2>&1 | grep -E "(Detecting|Transcribing)"
    
    if [ -f "/tmp/test_recording.json" ]; then
        TEXT=$(cat /tmp/test_recording.json | jq -r '.text')
        echo "   ✓ Transcription: $TEXT"
    else
        echo "   ✗ Transcription failed"
    fi
    
    # Cleanup
    rm -f "$TEST_WAV" /tmp/test_recording.*
else
    echo "   ✗ Recording failed"
fi

echo ""
echo "3. Checking Hammerspoon state..."
if pgrep -x "Hammerspoon" > /dev/null; then
    echo "   ✓ Hammerspoon running"
    
    # Check if module loads
    if hs -c "require('push_to_talk'); print('OK')" 2>/dev/null | grep -q "OK"; then
        echo "   ✓ push_to_talk module loads"
    else
        echo "   ✗ push_to_talk module failed to load"
    fi
else
    echo "   ✗ Hammerspoon not running"
fi

echo ""
echo "4. Recent recording attempts:"
ls -lt ~/Documents/VoiceNotes/ 2>/dev/null | head -5 | awk '{print "   " $9 " " $10 " " $11}'

echo ""
echo "5. Recent log entries:"
tail -3 ~/Documents/VoiceNotes/tx_logs/tx-$(date +%F).jsonl 2>/dev/null | jq -r '"\(.ts) \(.kind) duration:\(.duration_sec)s"' | sed 's/^/   /'

echo ""
echo "=== End Debug Test ==="
