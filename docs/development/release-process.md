# Release process

Personal project friendly, minimal ceremony, reproducible.

## Prepare
- Ensure README and tests/README are accurate
- Create ptt_config.lua.sample with safe defaults (LOG_ENABLED=false)
- Confirm no personal data in repo (logs, symlinks to local audio)

## Development workflow
- Branch per feature: 'feature/auto-mode-switch', 'feature/ui-overlay', etc.
- Keep commits small and focused; reference the area in the subject, e.g., 'ptt:', 'ui:', 'refine:'
- Open a PR even for personal repos to get a clean diff and checklist

## Versioning
- Update CHANGELOG.md under a new heading (e.g., v0.1.1)
- Tag and push:
  git tag -a v0.1.1 -m "<short summary>"
  git push origin v0.1.1

## Pre-release checklist
- Smoke: short clip and long clip succeed; paste behavior matches policy
- If refine enabled: verify a short and long refine, and one timeout path
- Logs: confirm 'auto_mode_decision' and 'paste_decision' entries look correct

## GitHub Release
- Create a release from the tag
- Include highlights, known issues, and upgrade notes

## Optional: Homebrew Tap (later)
- Create repo: cliffmin/homebrew-tap
- Add formula macos-ptt-dictation.rb (see dist/HomebrewFormula)
- Users then run two separate commands:
  brew tap cliffmin/tap
  brew install macos-ptt-dictation

## Optional: VoxCompose release
- In voxcompose repo: build shaded jar and attach to GitHub Release
- Provide a tiny launcher script named 'voxcompose' in PATH
- Optional tap formula (voxcompose.rb)

## Rollback
- Checkout the last good tag, e.g., 'git checkout v0.1.0'
- Re-run the smoke tests
- If needed, cut a hotfix tag 'v0.1.1'
