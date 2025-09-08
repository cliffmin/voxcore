#!/bin/bash

# Generate golden test dataset using macOS text-to-speech
# Creates synthetic audio files with known-accurate transcriptions

set -euo pipefail

GOLDEN_DIR="tests/fixtures/golden"
VOICE="Samantha"  # High-quality macOS voice
RATE=180         # Speaking rate (words per minute)

echo "=== Generating Golden Test Dataset ==="
echo "Using voice: $VOICE at ${RATE}wpm"
echo ""

# Create directory structure
mkdir -p "$GOLDEN_DIR"/{micro,short,medium,long}

# Function to generate audio and save transcript
generate_sample() {
    local category="$1"
    local name="$2"
    local text="$3"
    local output_dir="$GOLDEN_DIR/$category"
    
    echo "Generating $category/$name..."
    
    # Save the exact text
    echo "$text" > "$output_dir/${name}.txt"
    
    # Generate audio using macOS say command
    say -v "$VOICE" -r "$RATE" -o "$output_dir/${name}_raw.aiff" "$text"
    
    # Convert to 16kHz mono WAV (matching Whisper expectations)
    ffmpeg -i "$output_dir/${name}_raw.aiff" \
           -ar 16000 \
           -ac 1 \
           -c:a pcm_s16le \
           -y \
           "$output_dir/${name}.wav" 2>/dev/null
    
    # Remove intermediate file
    rm "$output_dir/${name}_raw.aiff"
    
    # Create metadata JSON
    cat > "$output_dir/${name}.json" << EOF
{
  "name": "$name",
  "category": "$category",
  "text": "$text",
  "voice": "$VOICE",
  "rate": $RATE,
  "duration_estimate": $(echo "$text" | wc -w | awk "{print \$1 * 60 / $RATE}"),
  "word_count": $(echo "$text" | wc -w),
  "char_count": ${#text}
}
EOF
}

# ============ MICRO SAMPLES (< 2 seconds) ============

generate_sample "micro" "greeting" \
"Hello, world!"

generate_sample "micro" "confirmation" \
"Yes, that's correct."

generate_sample "micro" "quick_command" \
"Open the terminal."

# ============ SHORT SAMPLES (2-10 seconds) ============

generate_sample "short" "technical_terms" \
"The API endpoint returns JSON data with a status code of 200. Please check the GitHub repository for the latest JavaScript implementation."

generate_sample "short" "punctuation_test" \
"Hello, how are you today? That's wonderful! I'll see you at 3:30 PM. Don't forget: bring your laptop, charger, and notebook."

generate_sample "short" "numbers_dates" \
"The meeting is scheduled for December 15th, 2024 at 2:45 PM. We have 12 participants from 5 different departments."

# ============ MEDIUM SAMPLES (10-30 seconds) ============

generate_sample "medium" "code_description" \
"The function takes two parameters: an array of integers and a target value. It uses a hash map to store seen values and their indices. For each element, it checks if the complement exists in the map. If found, it returns the indices. Otherwise, it adds the current element to the map. The time complexity is O of n and the space complexity is also O of n. This is an optimal solution for the two-sum problem."

generate_sample "medium" "with_pauses" \
"Let me explain the architecture. First, we have the presentation layer. Then, the business logic layer handles all the processing. Finally, the data access layer communicates with the database. Each layer is independent and loosely coupled. This separation of concerns makes the system more maintainable."

# ============ LONG SAMPLES (30+ seconds) ============

generate_sample "long" "documentation" \
"Welcome to the push-to-talk dictation system documentation. This system provides seamless voice-to-text functionality for macOS users. To get started, you'll need to install Hammerspoon, which handles the automation and hotkey management. Next, install ffmpeg for audio capture and processing. The system uses OpenAI's Whisper model for transcription, running entirely offline on your local machine. Configuration is managed through a Lua config file where you can customize various parameters including the transcription model, audio quality settings, and text processing options. The default hotkey is F13, which you hold down while speaking. When you release the key, the audio is automatically transcribed and pasted at your cursor position. For longer recordings, you can use Shift plus F13 to toggle recording mode. All recordings are saved locally in your Documents folder under VoiceNotes, organized by timestamp. The system includes advanced features like automatic punctuation, paragraph formatting based on pause duration, and customizable text replacements for common terms."

generate_sample "long" "technical_explanation" \
"Let me walk you through the implementation of a binary search tree. A binary search tree, or BST, is a hierarchical data structure that organizes data in a sorted manner. Each node in the tree contains a value and can have up to two children: a left child and a right child. The fundamental property of a BST is that for any given node, all values in its left subtree are less than the node's value, and all values in its right subtree are greater than the node's value. This property enables efficient searching, insertion, and deletion operations. To search for a value, we start at the root and compare the target with the current node. If they match, we've found our value. If the target is less, we go left; if greater, we go right. This process continues until we find the value or reach a null node. The average time complexity for these operations is O of log n, where n is the number of nodes. However, in the worst case of an unbalanced tree, it degrades to O of n. To maintain balance, we can use self-balancing variants like AVL trees or red-black trees."

# ============ EDGE CASES ============

generate_sample "short" "edge_acronyms" \
"API, JSON, HTML, CSS, SQL, NoSQL, GitHub, JavaScript, TypeScript, iOS, macOS, URLs, IDs."

generate_sample "short" "edge_disfluencies" \
"Um, let me think about that. Uh, well, you know, it's like, okay, so basically, yeah."

# ============ SUMMARY ============

echo ""
echo "=== Golden Dataset Generated ==="
echo ""
find "$GOLDEN_DIR" -name "*.wav" -exec ls -lh {} \; | awk '{print $9 ": " $5}'
echo ""
echo "Total samples: $(find "$GOLDEN_DIR" -name "*.wav" | wc -l)"
echo "Total size: $(du -sh "$GOLDEN_DIR" | cut -f1)"
echo ""
echo "Next steps:"
echo "1. Run accuracy tests: bash scripts/test_accuracy.sh"
echo "2. Compare against your transcription"
