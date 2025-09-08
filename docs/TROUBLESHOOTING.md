# Troubleshooting

Permissions
- Accessibility: allow Hammerspoon to paste
- Microphone: allow ffmpeg
- Screen Recording: if you record demos with scripts/generate_demo_gif.sh

Common issues
- ffmpeg not found: brew bundle --no-lock --file "$(pwd)/Brewfile" or brew install ffmpeg
- whisper not found: pipx install --include-deps openai-whisper; ensure ~/.local/bin is on PATH
- No paste: check Accessibility permission; confirm Hammerspoon is running; see JSONL logs for paste_decision
- Refine timeouts: start Ollama first or run scripts/setup_ollama_service.zsh; increase timeouts in config; baseline paste still occurs on fallback

Logs
- tail -f ~/Documents/VoiceNotes/tx_logs/tx-$(date +%F).jsonl

Help
- Open an issue with a short description, your macOS version, and the relevant log snippet (redact personal text if needed)

