# Staging formula for CI automation.
# The canonical formula lives at https://github.com/cliffmin/homebrew-tap/blob/main/Formula/voxcore.rb
# On each tagged release, .github/workflows/update-formula.yml updates the url and sha256 fields below.
class Voxcore < Formula
  desc "Offline push-to-talk dictation for macOS with on-device transcription"
  homepage "https://github.com/cliffmin/voxcore"
  url "https://github.com/cliffmin/voxcore/archive/refs/tags/v0.7.0.tar.gz"
  sha256 "aaca860b5c3862ceade43f1b07a921761f88aa854d5ae9f75804c1f24d0ff6f8"
  license "MIT"
  head "https://github.com/cliffmin/voxcore.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "ffmpeg"
  depends_on "openjdk@17"
  depends_on "whisper-cpp" => :recommended

  def install
    # Install all files to libexec
    libexec.install Dir["*"]

    # Build Java post-processor
    cd libexec/"whisper-post-processor" do
      system "./gradlew", "--no-daemon", "clean", "shadowJar"
    end

    # Create wrapper scripts
    (bin/"voxcore-install").write <<~EOS
      #!/usr/bin/env bash
      set -euo pipefail
      REPO="#{libexec}"

      echo "==> VoxCore Installation Helper"

      # Check dependencies
      command -v ffmpeg >/dev/null || { echo "ERROR: ffmpeg required"; exit 1; }

      # Setup Hammerspoon integration
      mkdir -p "$HOME/.hammerspoon"

      # Symlink Lua files
      for lua_file in push_to_talk_v2.lua whisper_wrapper.lua; do
        if [ -f "$REPO/hammerspoon/$lua_file" ]; then
          ln -sf "$REPO/hammerspoon/$lua_file" "$HOME/.hammerspoon/$lua_file"
        fi
      done

      # Create config if it doesn't exist
      if [ ! -f "$HOME/.hammerspoon/ptt_config.lua" ]; then
        cp "$REPO/hammerspoon/ptt_config.lua.sample" "$HOME/.hammerspoon/ptt_config.lua"
        echo "Created config: ~/.hammerspoon/ptt_config.lua"
      else
        echo "Config exists: ~/.hammerspoon/ptt_config.lua"
      fi

      echo ""
      echo "Next steps:"
      echo "  1. Reload Hammerspoon (Cmd+Opt+Ctrl+R)"
      echo "  2. Grant Microphone and Accessibility permissions"
      echo "  3. Test: Hold Cmd+Opt+Ctrl+Space to record"
      echo ""
      echo "Optional: Start daemon with 'brew services start voxcore'"
    EOS
    chmod "+x", bin/"voxcore-install"

    (bin/"voxcore-daemon").write <<~EOS
      #!/usr/bin/env bash
      set -euo pipefail
      exec "#{Formula["openjdk@17"].opt_bin}/java" \
        -cp "#{libexec}/whisper-post-processor/build/libs/whisper-post.jar" \
        com.cliffmin.whisper.daemon.PTTServiceDaemon
    EOS
    chmod "+x", bin/"voxcore-daemon"

    (bin/"whisper-post").write <<~EOS
      #!/usr/bin/env bash
      set -euo pipefail
      exec "#{Formula["openjdk@17"].opt_bin}/java" \
        -jar "#{libexec}/whisper-post-processor/build/libs/whisper-post.jar" "$@"
    EOS
    chmod "+x", bin/"whisper-post"
  end

  service do
    run [opt_bin/"voxcore-daemon"]
    keep_alive true
    log_path var/"log/voxcore-daemon.log"
    error_log_path var/"log/voxcore-daemon.log"
    working_dir var
  end

  def caveats
    <<~EOS
      VoxCore requires additional setup:

      0. Install Hammerspoon if not already installed:
         brew install --cask hammerspoon

      1. Install Hammerspoon integration:
         voxcore-install

      2. Grant permissions in System Settings:
         * Microphone access for Hammerspoon
         * Accessibility access for Hammerspoon

      3. Reload Hammerspoon:
         * Click Hammerspoon menu bar icon -> "Reload Config"
         * Or press: Cmd+Opt+Ctrl+R

      4. (Optional) Start background daemon for audio padding:
         brew services start voxcore

      Usage:
         * Hold Cmd+Opt+Ctrl+Space to record
         * Release to transcribe and paste
         * Add Shift for toggle mode

      Configuration: ~/.hammerspoon/ptt_config.lua
      Documentation: https://github.com/cliffmin/voxcore
    EOS
  end

  test do
    assert_path_exists libexec/"hammerspoon/push_to_talk_v2.lua"
    assert_path_exists libexec/"whisper-post-processor/build/libs/whisper-post.jar"
    system bin/"whisper-post", "--version"
  end
end
