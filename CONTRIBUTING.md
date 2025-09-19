# Contributing

Thanks for your interest in improving VoxCore.

## How to propose a change
- Open an issue describing the problem or the proposed change
- Fork and create a branch 'feature/<short-name>'
- Keep diffs focused; avoid broad refactors

## Development quickstart
- Edit hammerspoon/push_to_talk.lua and reload Hammerspoon (menu → Reload Config)
- Short smoke: record a 2–4s clip and a 10–15s clip; confirm paste and artifacts
- Logs: tail -f ~/Documents/VoiceNotes/tx_logs/tx-$(date +%F).jsonl

## Style
- Lua: small, idiomatic; keep functions short and pure where possible
- Shell: POSIX sh where practical; zsh scripts are fine if clearly marked
- Use 2-space indent and LF endings (see .editorconfig)

## Tests and validation
- Run tests: `make test-java-all`
- If you add a user-facing knob or behavior change, add a note to README and CHANGELOG

## Commit messages
- Use a short area prefix: 'ptt:', 'ui:', 'refine:', 'docs:', 'tests:'
- Example: 'ptt: auto-mode decision and logs'

## License
- By contributing, you agree that your contributions are licensed under the MIT License in LICENSE

