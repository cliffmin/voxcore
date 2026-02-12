#!/usr/bin/env bash
# Generate synthetic golden-public test fixtures using macOS 'say' + ffmpeg
# These are committed to the repo for CI benchmark testing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="$REPO_ROOT/tests/fixtures/golden-public"

mkdir -p "$OUT_DIR/short" "$OUT_DIR/medium" "$OUT_DIR/long"

generate() {
  local category="$1"
  local name="$2"
  local text="$3"
  local rate="${4:-180}"

  local dir="$OUT_DIR/$category"
  local aiff="$dir/${name}.aiff"
  local wav="$dir/${name}.wav"
  local txt="$dir/${name}.txt"

  echo "  Generating $category/$name..."

  # Generate speech with macOS say
  say -r "$rate" -o "$aiff" "$text"

  # Convert to 16kHz mono WAV (whisper-cpp format)
  ffmpeg -y -i "$aiff" -ar 16000 -ac 1 -sample_fmt s16 "$wav" 2>/dev/null

  # Write expected transcript
  echo -n "$text" > "$txt"

  # Cleanup intermediate file
  rm -f "$aiff"
}

echo "=== Generating golden-public fixtures ==="

# --- SHORT (<21s) ---
generate short "simple_sentence" \
  "The quick brown fox jumps over the lazy dog."

generate short "technical_terms" \
  "The API key is required for authentication. Check the configuration file."

generate short "proper_nouns" \
  "I worked on the VoxCore project using GitHub and Hammerspoon on macOS."

generate short "numbers_and_dates" \
  "The meeting is scheduled for January 15th at 3 PM in room 204."

# --- MEDIUM (21-45s) ---
generate medium "multi_sentence" \
  "Software development requires careful planning and execution. The team decided to use a microservices architecture for better scalability. Each service communicates through well defined API endpoints. Testing is automated using continuous integration pipelines. The deployment process follows standard best practices for reliability." \
  160

generate medium "technical_explanation" \
  "The transcription engine uses whisper cpp for on device speech recognition. Audio is captured at sixteen kilohertz mono through ffmpeg. The Java post processor handles text cleanup including merged word separation, sentence boundary detection, and capitalization. All processing happens locally without any network access." \
  160

generate medium "mixed_content" \
  "VoxCore version zero point seven introduced dynamic model selection. Short recordings under twenty one seconds use the base english model for faster processing around five hundred milliseconds. Longer recordings automatically switch to the medium english model which provides better accuracy. Users can configure the threshold in their config file." \
  160

generate medium "conversational" \
  "I think the best approach is to start with the basic implementation and then iterate. We should focus on getting the core functionality working first. Once that is stable we can add the additional features like vocabulary integration and debug logging. The important thing is to maintain backward compatibility throughout the process." \
  160

# --- LONG (>45s) ---
generate long "full_paragraph" \
  "Voice to text technology has improved dramatically in recent years. Modern speech recognition systems can achieve accuracy rates above ninety five percent for clear speech. The key innovation has been the development of transformer based models that understand context and language patterns. These models can run efficiently on consumer hardware thanks to optimizations like quantization and model distillation. For developers building voice applications the challenge is not just accuracy but also latency, privacy, and reliability. Local processing eliminates network dependencies and ensures user data stays on device. This is particularly important for sensitive applications in healthcare, legal, and business contexts where confidentiality is critical." \
  160

generate long "technical_walkthrough" \
  "Let me walk you through the VoxCore architecture. When you press the hotkey, Hammerspoon starts recording audio through ffmpeg using the avfoundation framework. The audio is saved as a sixteen kilohertz mono WAV file. Once you release the hotkey, the recording stops and Hammerspoon calls the VoxCore command line interface. The CLI loads your configuration, reads any vocabulary hints from VoxCompose, and invokes whisper cpp for transcription. The raw transcript then passes through a ten stage post processing pipeline. This pipeline handles merged word separation, disfluency removal, sentence boundaries, capitalization, punctuation, and dictionary corrections. The final clean text is returned to Hammerspoon which pastes it at your cursor position." \
  150

generate long "project_overview" \
  "VoxCore is an open source push to talk transcription tool for macOS. It provides universal voice input that works in any application. The project uses a plugin architecture where the core handles fast stateless transcription and optional plugins add advanced features. VoxCompose is the official plugin that provides machine learning based refinement including self learning corrections and vocabulary building. Everything runs locally on your Mac with zero cloud dependencies. The system is designed for privacy and speed, processing most recordings in under one second. It supports automatic model selection based on recording duration, choosing between a fast model for short clips and a more accurate model for longer recordings." \
  160

generate long "development_process" \
  "The development workflow for this project follows standard best practices. Changes are made on feature branches and submitted as pull requests. The continuous integration pipeline runs Java unit tests, validation checks, code quality analysis, and benchmark regression tests. All required checks must pass before merging. Releases follow semantic versioning with the version number tracked in the Gradle build file and changelog. When releasing, we create a git tag which triggers the release workflow to build artifacts and create a GitHub release. The Homebrew formula in the tap repository is then updated with the new version URL and checksum. Users upgrade by running brew update and brew upgrade." \
  160

echo ""
echo "=== Done ==="
echo "Generated fixtures:"
find "$OUT_DIR" -name "*.wav" | wc -l | tr -d ' '
echo " WAV files"
find "$OUT_DIR" -name "*.txt" | wc -l | tr -d ' '
echo " TXT files"
du -sh "$OUT_DIR"
