#!/bin/bash

# Generate comprehensive golden test dataset with diverse voices and speaking styles
# Includes perfect speech, natural speech with disfluencies, and challenging technical terms

set -euo pipefail

GOLDEN_DIR="tests/fixtures/golden"

echo "=== Generating Enhanced Golden Test Dataset ==="
echo "Creating diverse samples with multiple voices and speaking styles"
echo ""

# Create directory structure
mkdir -p "$GOLDEN_DIR"/{micro,short,medium,long,challenging,natural}

# Function to generate audio with specific voice and save transcript
generate_sample() {
    local category="$1"
    local name="$2"
    local voice="$3"
    local rate="$4"
    local text="$5"
    local output_dir="$GOLDEN_DIR/$category"
    
    echo "Generating $category/$name (voice: $voice, rate: $rate wpm)..."
    
    # Save the exact text
    echo "$text" > "$output_dir/${name}.txt"
    
    # Generate audio using macOS say command
    say -v "$voice" -r "$rate" -o "$output_dir/${name}_raw.aiff" "$text"
    
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
  "voice": "$voice",
  "rate": $rate,
  "style": "$(echo $name | grep -oE 'perfect|natural|technical' || echo 'standard')",
  "duration_estimate": $(echo "$text" | wc -w | awk "{print \$1 * 60 / $rate}"),
  "word_count": $(echo "$text" | wc -w),
  "char_count": ${#text}
}
EOF
}

# Available macOS voices (adjust based on your system)
# Use 'say -v ?' to see all available voices
VOICE_MALE="Daniel"        # British male
VOICE_FEMALE="Samantha"    # American female
VOICE_MALE_US="Alex"       # American male
VOICE_FEMALE_UK="Kate"     # British female

# Speaking rates
RATE_SLOW=150
RATE_NORMAL=180
RATE_FAST=220

# ============ PERFECT SPEECH (Public speaking style) ============

generate_sample "short" "perfect_male_presentation" "$VOICE_MALE" "$RATE_SLOW" \
"Good morning, everyone. Today, I will demonstrate our new push-to-talk dictation system. This innovative solution provides seamless voice-to-text functionality for macOS users."

generate_sample "short" "perfect_female_technical" "$VOICE_FEMALE" "$RATE_NORMAL" \
"The application programming interface returns JavaScript Object Notation data with a status code of two hundred. Please check the GitHub repository for implementation details."

generate_sample "medium" "perfect_male_documentation" "$VOICE_MALE_US" "$RATE_NORMAL" \
"Welcome to the comprehensive documentation for our system. First, we will cover the installation process. Next, we will explore the configuration options. Then, we will discuss advanced features. Finally, we will review troubleshooting steps. Each section includes detailed examples and best practices. Our goal is to provide you with all the information needed for successful implementation."

# ============ NATURAL SPEECH (With disfluencies and natural patterns) ============

generate_sample "natural" "natural_thinking" "$VOICE_FEMALE" "$RATE_NORMAL" \
"Um, let me think about that for a moment. So, basically, uh, what we're trying to do here is, you know, create a system that can, like, handle voice input efficiently."

generate_sample "natural" "natural_explanation" "$VOICE_MALE" "$RATE_NORMAL" \
"Okay, so, um, the way this works is pretty straightforward. You press the key, and then, uh, you speak. When you're done, you just, you know, release the key and it automatically, um, transcribes everything."

generate_sample "natural" "natural_repetitions" "$VOICE_FEMALE_UK" "$RATE_FAST" \
"The the system is designed to handle handle multiple inputs. We need to to configure the settings properly. It's it's important to test test everything thoroughly."

generate_sample "natural" "natural_pauses" "$VOICE_MALE_US" "$RATE_SLOW" \
"Let me explain the architecture. \
So first, we have the presentation layer. \
Then, um, the business logic layer handles processing. \
And finally, the data layer communicates with the database. \
Each layer is, you know, independent."

# ============ CHALLENGING TECHNICAL TERMS (Known mishears) ============

generate_sample "challenging" "technical_mishears_1" "$VOICE_FEMALE" "$RATE_NORMAL" \
"We need to check the GitHub repositories for symlinks. The JSON configuration uses NoSQL database with Jira integration."

generate_sample "challenging" "technical_mishears_2" "$VOICE_MALE" "$RATE_NORMAL" \
"The XDG configuration paths contain symlinks to dedupe the repositories. Our NoSQL solution integrates with Avalara tax systems."

generate_sample "challenging" "technical_mishears_3" "$VOICE_FEMALE_UK" "$RATE_FAST" \
"After we retest the complexity metrics, we'll commit the symlink changes to GitHub. The JSON API handles DynamoDB and Salesforce OAuth."

generate_sample "challenging" "technical_acronyms" "$VOICE_MALE_US" "$RATE_NORMAL" \
"Our API uses JSON for data exchange. We support HTML, CSS, SQL, and NoSQL databases. The iOS and macOS applications share URLs and unique IDs."

# ============ MIXED COMPLEXITY SAMPLES ============

generate_sample "medium" "mixed_technical_natural" "$VOICE_FEMALE" "$RATE_NORMAL" \
"So, um, when we're dealing with the GitHub repositories, we need to, you know, make sure the symlinks are properly configured. The JSON data should be, uh, validated before we dedupe the records in the NoSQL database."

generate_sample "long" "mixed_presentation_disfluencies" "$VOICE_MALE" "$RATE_NORMAL" \
"Good morning everyone. Today I want to, um, discuss our approach to handling complexity metrics in the system. So, basically, we have three main components. First, uh, the GitHub integration layer, which manages our repositories and symlinks. Second, the, you know, processing engine that handles JSON data and communicates with both SQL and NoSQL databases. And finally, um, the presentation layer that, that renders everything for the user. Now, let me explain how these components work together. The GitHub layer, uh, it monitors for changes and triggers our dedupe process. This process, um, uses complexity metrics to determine which records to keep. The data is then, you know, stored in our NoSQL database with proper indexing for fast retrieval."

# ============ EDGE CASES ============

generate_sample "short" "edge_numbers_mixed" "$VOICE_FEMALE" "$RATE_FAST" \
"The meeting is at 3:30 PM on December 15th, 2024. We have 12 GitHub repositories with over 1,000 symlinks across 5 different environments."

generate_sample "short" "edge_punctuation_complex" "$VOICE_MALE" "$RATE_NORMAL" \
"Important: Check the JSON configuration! The API endpoint (version 2.0) returns data; however, authentication is required. Don't forget: validate input/output."

generate_sample "micro" "edge_single_word" "$VOICE_FEMALE" "$RATE_NORMAL" \
"GitHub"

generate_sample "micro" "edge_two_words" "$VOICE_MALE" "$RATE_NORMAL" \
"symlinks configured"

# ============ REAL-WORLD SCENARIOS ============

generate_sample "medium" "realworld_debugging" "$VOICE_FEMALE" "$RATE_NORMAL" \
"Okay, so I'm looking at the error log here. Um, it says the JSON parsing failed at line 42. Let me check the GitHub commit history. Oh, I see, someone changed the symlink structure yesterday. We'll need to retest this and update the complexity metrics. The NoSQL query is also returning unexpected results, probably because of the dedupe process."

generate_sample "long" "realworld_standup" "$VOICE_MALE_US" "$RATE_FAST" \
"Good morning team. Quick update on my progress. Yesterday, I finished implementing the GitHub webhook integration. The JSON payload is now properly parsed and stored in our NoSQL database. Um, I did run into some issues with the symlinks in the development environment, but I managed to resolve them by updating the XDG configuration paths. Today, I'll be working on the dedupe algorithm to improve our complexity metrics. I also need to retest the Avalara tax integration after the latest API changes. Oh, and I'll be reviewing the pull request for the OAuth implementation this afternoon. Any questions?"

# ============ ACCENTS AND VARIATIONS ============

# Irish accent
if say -v "Moira" "test" > /dev/null 2>&1; then
    generate_sample "short" "accent_irish" "Moira" "$RATE_NORMAL" \
    "We'll be updating the GitHub repositories today. The JSON configuration needs reviewing, and the symlinks should be checked."
fi

# Indian accent  
if say -v "Veena" "test" > /dev/null 2>&1; then
    generate_sample "short" "accent_indian" "Veena" "$RATE_NORMAL" \
    "Please check the API documentation for proper JSON formatting. The NoSQL database queries are optimized for performance."
fi

# ============ SUMMARY ============

echo ""
echo "=== Enhanced Golden Dataset Generated ==="
echo ""
echo "Categories created:"
echo "  - Perfect speech (presentation style)"
echo "  - Natural speech (with disfluencies)"
echo "  - Challenging technical terms"
echo "  - Mixed complexity samples"
echo "  - Real-world scenarios"
echo ""
find "$GOLDEN_DIR" -name "*.wav" | wc -l | xargs echo "Total audio files:"
du -sh "$GOLDEN_DIR" | cut -f1 | xargs echo "Total size:"
echo ""
echo "Voice diversity:"
echo "  - Male: $VOICE_MALE, $VOICE_MALE_US"
echo "  - Female: $VOICE_FEMALE, $VOICE_FEMALE_UK"
echo "  - Multiple speaking rates: $RATE_SLOW, $RATE_NORMAL, $RATE_FAST wpm"
echo ""
echo "Next steps:"
echo "1. Run accuracy tests: bash scripts/test_accuracy.sh"
echo "2. Compare transcription quality across different sample types"
echo "3. Identify which speaking styles work best with Whisper"
