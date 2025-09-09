# Warp Project Index

Repo: macos-ptt-dictation — Privacy-first push-to-talk dictation for macOS

Summary
- Hold F13 to record, release to paste; runs fully offline; integrates with Hammerspoon and optional LLM refinement.

Key directories
- hammerspoon/: Lua automation (push_to_talk.lua, config)
- scripts/: install/test/benchmark utilities
- tests/: fixtures, smoke and integration tests

Quick start
- brew install --cask hammerspoon && brew install ffmpeg
- bash ./scripts/install.sh

Indexing guidance for Warp
- Prioritize: hammerspoon/, scripts/, tests/, README.md
- Skip: go/, demos/, docs/, .venv/, tests/fixtures/personal/, tests/fixtures/samples/, dist/, .idea/, .vscode/

Notes
- Offline-first; sensitive audio/transcripts should not be committed.

