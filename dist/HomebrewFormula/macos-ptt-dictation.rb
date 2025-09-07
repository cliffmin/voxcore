class MacosPttDictation < Formula
  desc "macOS push-to-talk dictation via Hammerspoon, ffmpeg, and Whisper CLI"
  homepage "https://github.com/cliffmin/macos-ptt-dictation"
  url "https://github.com/cliffmin/macos-ptt-dictation/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "<fill-with-sha256-of-tarball>"
  license "MIT"

  depends_on "ffmpeg"

  def install
    libexec.install Dir["*"]
    (bin/"ptt-install").write <<~EOS
      #!/usr/bin/env bash
      set -Eeuo pipefail
      REPO="#{libexec}"
      echo "==> macos-ptt-dictation install helper"
      command -v ffmpeg >/dev/null || { echo "ffmpeg required"; exit 1; }
      echo "Note: install Whisper CLI via pipx:" \
           "python3 -m pip install --user pipx; python3 -m pipx ensurepath || true; pipx install --include-deps openai-whisper"
      mkdir -p "$HOME/.hammerspoon"
      ln -sf "$REPO/hammerspoon/push_to_talk.lua" "$HOME/.hammerspoon/push_to_talk.lua"
      if [ ! -f "$HOME/.hammerspoon/ptt_config.lua" ]; then
        cp "$REPO/hammerspoon/ptt_config.lua.sample" "$HOME/.hammerspoon/ptt_config.lua"
        echo "Created sample config at ~/.hammerspoon/ptt_config.lua"
      fi
      echo "Reload Hammerspoon and press F13 to test"
    EOS
    chmod "+x", (bin/"ptt-install")
  end

  def caveats
    <<~EOS
      After install:
        1) Install Whisper CLI via pipx (see brew output above).
        2) Run 'ptt-install' to symlink the Hammerspoon module and create a sample config.
        3) Reload Hammerspoon and grant Microphone + Accessibility permissions.
    EOS
  end

  test do
    assert_predicate libexec/"hammerspoon/push_to_talk.lua", :exist?
  end
end
