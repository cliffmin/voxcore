# Release process (MVP)

## Prepare
- Ensure README and tests/README are accurate
- Create ptt_config.lua.sample with safe defaults (LOG_ENABLED=false)
- Confirm no personal data in repo (logs, symlinks to local audio)

## Versioning
- Update CHANGELOG.md under a new heading (e.g., v0.1.0)
- Tag and push:
  git tag -a v0.1.0 -m "Initial public MVP"
  git push origin v0.1.0

## GitHub Release
- Create a release from tag v0.1.0
- Add highlights, screenshot or GIF (optional)

## Optional: Homebrew Tap (later)
- Create repo: cliffmin/homebrew-tap
- Add formula macos-ptt-dictation.rb (see dist/HomebrewFormula)
- Users then:
  brew tap cliffmin/tap
  brew install macos-ptt-dictation

## Optional: VoxCompose release
- In voxcompose repo: build shaded jar and attach to GitHub Release
- Add a tap formula (voxcompose.rb) or provide direct jar usage
