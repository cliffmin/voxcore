# VoxCore

[![CI](https://github.com/cliffmin/voxcore/actions/workflows/ci.yml/badge.svg)](https://github.com/cliffmin/voxcore/actions/workflows/ci.yml) [![codecov](https://codecov.io/gh/cliffmin/voxcore/branch/main/graph/badge.svg)](https://codecov.io/gh/cliffmin/voxcore) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) ![macOS](https://img.shields.io/badge/macOS-11%2B-blue) ![Java 17+](https://img.shields.io/badge/Java-17%2B-orange)

**Fast, private, secure transcription for macOS.** Hold a hotkey anywhere—ChatGPT, Slack, email, code—speak, and your words paste at the cursor in under a second. Your voice never touches the cloud. Your recordings are automatically stored and yours forever.

100% local AI. No tokens, no subscriptions, no compromises.

<!-- Uncomment when demo.gif is generated via: make demo-gif
![Demo](docs/assets/demo.gif)
-->

---

## Universal Voice Infrastructure for the AI Era

**AI tools are exploding.** ChatGPT, Claude, Cursor, Perplexity—you're probably using 3-5 AI apps daily, each with different (or missing) voice input. The bottleneck? Getting your thoughts into AI fast enough.

**But it's not just AI.** Slack messages, emails, documents, code comments—typing everywhere is slow. Voice input is fragmented or missing entirely.

### The Problem

You're working across multiple AI apps and tools:
- **ChatGPT**: Has voice (cloud-based, recordings lost)
- **Claude**: No voice (type or use mobile)
- **Cursor**: Has voice (burns your API tokens)
- **Perplexity**: Has voice (cloud-based)
- **Slack, email, docs, Linear, Notion**: No voice at all

**Result:** Typing the same prompts over and over. Avoiding emails because proper writing takes too long. Losing nuance and speed.

### Why Voice Matters for AI

**1. Speed of thought**
- Speaking: 150-200 words/minute
- Typing: 40-60 words/minute
- **Voice is 3-4x faster**

**2. Better AI results**
- Verbal explanations include nuance, context, and detail
- More data = better AI responses
- Natural speech captures what typing misses

**3. Iterate faster**
- Quick voice prompts → instant AI feedback
- Rapid iteration = better outcomes
- Essential when you're prompting 20-50 times/day

**4. Reduce friction**
- Hold hotkey, speak, release
- No app switching, no interruption
- Stay in flow state

### VoxCore: Universal Voice Infrastructure

**One hotkey. Transcribe and paste anywhere. Consistent workflow.**

VoxCore solves the fragmented voice input problem:
- ✅ **Universal paste** - ChatGPT, Slack, email, docs, anywhere you type
- ✅ **Private** - Voice never uploaded, 100% on-device
- ✅ **Fast** - Sub-second transcription, comparable to cloud
- ✅ **Fail-safe** - Recordings saved locally, never lost
- ✅ **Free** - No tokens burned, no rate limits
- ✅ **Consistent** - Same workflow, every app, every time

### Right Now: Production-Ready Transcription

**VoxCore delivers clean, natural text instantly.** Filler words gone (um, uh), pauses removed, repeat words merged, run-on sentences fixed. What you say becomes readable prose - paste anywhere.

**Perfect timing with AI tool explosion:** ChatGPT, Claude, Cursor, Perplexity, Copilot - you're jumping between 3-5+ AI apps daily. VoxCore lets you speak your prompts 3-4x faster than typing. More verbal context = richer explanations = better AI results. One consistent workflow across all apps.

### Future: Context-Aware Modes (Coming Soon)

Same recording, different output formats:

**AI Prompt Mode** (planned):
```
Optimized for AI parsing - shorter, structured, focused
```

**Email Mode** (planned):
```
"Hey tell them I can't make the 2pm meeting..."
→ Professional email with proper etiquette
```

**Journal Mode, Meeting Notes, Code Comments** (planned):
- Same voice input, optimized for different contexts
- Always have the original recording

**One hotkey, any output. Choose your mode.**

---

## Why VoxCore?

### 🔒 Your Voice Never Leaves Your Mac
- **100% on-device** - All processing happens locally
- **Zero cloud uploads** - Not "can work offline" but "never uploads, period"
- **Your data, your control** - No company has access to your recordings
- **No AI training on your voice** - Your speech stays private

### ⚡ As Fast As Cloud (But Local)
- **Sub-second transcription** - Comparable to ChatGPT's built-in voice
- **No network latency** - Process locally, paste instantly
- **Often faster than cloud** - No API overhead or rate limiting

### 🛡️ Secure By Default
- **Recordings saved forever** - WAV files you own, always accessible
- **No service dependency** - Not reliant on any company staying in business
- **Full audit trail** - Timestamped, versioned, traceable
- **Verify quality** - Original audio always available for re-transcription

### 💰 Zero Cost, No Limits
- **No API tokens** - Cursor/Warp burn tokens, VoxCore is free
- **No rate limits** - Transcribe 1000x/day if you want
- **No subscriptions** - Open source, free forever
- **Unlimited usage** - Really unlimited

### 🌐 Universal & Reliable
- **Works everywhere** - Any app where you can type
- **One workflow** - Same hotkey, consistent behavior
- **Offline-capable** - Planes, trains, anywhere
- **Never lose recordings** - Even if transcription fails, WAV is saved

## Quick Start

```bash
# Install dependencies (5 minutes)
brew install --cask hammerspoon
brew install ffmpeg whisper-cpp openjdk@17

# Clone and setup
git clone https://github.com/cliffmin/voxcore.git
cd voxcore
./scripts/setup/install.sh

# Optional: Better accuracy
make build-java
```

**Use anywhere:**
- Hold `Cmd+Alt+Ctrl+Space` → Speak → Release
- Text pastes at cursor in any app
- Recording saved to `~/Documents/VoiceNotes/`

## The Problem VoxCore Solves

**You're working across multiple AI apps daily** (ChatGPT, Claude, Cursor, Perplexity). Each has different or missing voice input. Some burn your API tokens. Some require internet. None save your recordings.

**You need voice input that:**
- Works the same everywhere
- Doesn't cost tokens
- Works offline
- Saves recordings as backup
- Keeps your voice private

**VoxCore provides universal transcription infrastructure** - one hotkey that works everywhere, with your voice and recordings staying on your Mac.

## Real-World Use Cases

### 1. Privacy-Critical Work
```
Healthcare: Doctor dictating patient notes
Legal: Lawyer recording case strategy  
Business: Executive discussing confidential plans

Concern: HIPAA/confidentiality/trade secrets
VoxCore: Voice never uploaded, fully compliant
```

### 2. AI Power Users
```
Developer: Prompting ChatGPT, Claude, Cursor 50x/day
Problem: Different voice input (or none), burns tokens
VoxCore: Same hotkey everywhere, $0 cost
```

### 3. Reliability Under Deadline
```
You: Spoke 5 min explanation to ChatGPT
ChatGPT: Error - recording lost
You: Panic

With VoxCore: WAV saved, retry transcription
```

### 4. Offline Productivity
```
Plane WiFi: Not working
You: Still need to prompt AI
VoxCore: Transcribes locally, works perfectly
```

## How It Compares

| Feature | VoxCore | ChatGPT Voice | Cursor | macOS Dictation |
|---------|---------|---------------|--------|-----------------|
| **Privacy** | ✅ Never uploaded | ❌ Cloud | ❌ API | ⚠️ Cloud |
| **Speed** | ✅ <1s | ✅ 1-2s | ⚠️ 2-3s | ❌ 3-5s |
| **Works Everywhere** | ✅ Any app | ❌ ChatGPT only | ❌ Cursor only | ✅ Any app |
| **Saves Recording** | ✅ WAV backup | ❌ Transient | ❌ Transient | ❌ No |
| **Offline** | ✅ Yes | ❌ Cloud required | ❌ API required | ❌ Cloud required |
| **Cost** | ✅ $0 | ⚠️ Subscription | ❌ Burns tokens | ✅ Free |
| **Rate Limits** | ✅ None | ⚠️ Has limits | ❌ Token limits | ⚠️ Unknown |

## Core Features

### Universal Transcription
- Works in every app where you can type
- Same hotkey, same workflow, consistent results
- Paste at cursor (ChatGPT, Slack, email, code, anywhere)

### Privacy & Security
- 100% on-device processing (verify with Little Snitch)
- Voice never uploaded to any server
- No telemetry or tracking
- Open source - audit the code
- HIPAA/GDPR-friendly by design

### Reliability
- WAV files always saved (`~/Documents/VoiceNotes/`)
- Can retry transcription if it fails
- Original audio preserved for quality verification
- Never lose work to cloud errors

### Performance
- Sub-second transcription for typical prompts
- Automatic model selection (speed/accuracy balance)
- Smart post-processing (removes "um", "uh", fixes punctuation)
- Often faster than cloud (no network latency)

### Stateless & Fast
- **Algorithmic processing only** - No ML models, no learning, no state
- **Deterministic output** - Same input = same output, always
- **Fast & predictable** - Pure algorithms (word separation, disfluency removal)
- **Optional ML enhancement** - VoxCompose plugin for advanced refinement

### Cost
- Zero API tokens consumed
- No rate limits or usage caps
- No subscriptions or hidden fees
- Free, unlimited, forever

## Where Your Data Lives

```
~/Documents/VoiceNotes/
├── 2025-Nov-15_09.30.00_AM/
│   ├── .version                      ← Version metadata
│   ├── 2025-Nov-15_09.30.00_AM.wav  ← Your recording (yours forever)
│   ├── 2025-Nov-15_09.30.00_AM.txt  ← Transcription
│   └── 2025-Nov-15_09.30.00_AM.json ← Whisper metadata
└── tx_logs/
    └── tx-2025-11-15.jsonl           ← Performance tracking
```

**You own these files:**
- No company has access
- Move/delete/backup as you wish
- Not dependent on any service
- Standard formats (WAV, TXT, JSON)

## Verify Privacy Yourself

```bash
# Install network monitor
brew install --cask little-snitch

# Or use tcpdump
sudo tcpdump -i any

# Use VoxCore and verify: zero network traffic during transcription
```

It's open source - audit the code, verify the claims.

## Documentation

- **[Setup Guide](docs/setup.md)** - Installation and configuration
- **[Usage Guide](docs/usage.md)** - How to use VoxCore
- **[Performance](PERFORMANCE.md)** - Benchmarks and speed improvements
- **[Configuration](docs/setup/configuration.md)** - Customize behavior
- **[Troubleshooting](docs/setup/troubleshooting.md)** - Common issues
- **[Contributing](CONTRIBUTING.md)** - Development guidelines
- **[Architecture](docs/development/architecture.md)** - System design
- **[Versioning](VERSIONING_QUICK_START.md)** - Releases and version management

## FAQ

**Q: Is my voice really never uploaded?**  
A: Correct. All processing is local. Verify with Little Snitch or tcpdump.

**Q: How's the accuracy?**  
A: Whisper-level (~95%+) with smart post-processing for cleanup.

**Q: Does it work offline?**  
A: Yes, 100%. Perfect for planes, trains, anywhere without internet.

**Q: What if transcription fails?**  
A: The WAV file is saved. Retry transcription or listen to the original audio.

**Q: Does it cost anything?**  
A: No. Zero tokens, zero subscriptions. MIT licensed, free forever.

**Q: Will it burn my API tokens?**  
A: No. VoxCore transcribes locally. Save tokens for actual AI inference.

**Q: What about HIPAA/GDPR?**  
A: Compliant by design (voice never leaves your device), but consult your legal team.

**Q: Can I customize the hotkey?**  
A: Yes. Edit `~/.hammerspoon/ptt_config.lua`.

## Roadmap

**Current (v0.4.3):**
- [x] Fast offline transcription (whisper-cpp)
- [x] Universal paste (works everywhere)
- [x] 100% private (never uploads)
- [x] WAV backup (always saved)
- [x] Smart post-processing
- [x] Custom dictionaries
- [x] Version tracking

**Planned:**
- [ ] Multi-mode plugins (journal, email, meeting modes)
- [ ] Quick-switch keybinds for different contexts
- [ ] Enhanced privacy tools (audio encryption)
- [ ] Multi-language optimization

## Plugin Architecture

**VoxCore is designed for extensibility.** The core stays lightweight, fast, and stateless. Advanced features come via opt-in plugins.

### Official Plugin: VoxCompose

[**VoxCompose**](https://github.com/cliffmin/voxcompose) is the official plugin for ML-based refinement (completely optional):

- **Adaptive learning** - Learns from your corrections
- **Context-aware casing** - Technical terms, proper nouns  
- **LLM refinement** - Optional AI-powered cleanup (local Ollama)
- **Stateful processing** - Builds user profile over time

**Install or not?** Your choice. VoxCore works perfectly standalone.

### Future: Community Extensions

Inspired by VS Code's extension marketplace, VoxCore is designed to support community-built plugins:

- **Journal mode** - Transform speech into journal entries
- **Meeting notes** - Structure as meeting minutes
- **Code comments** - Format for inline documentation
- **Custom workflows** - Build your own refinement logic

**Coming soon:** Plugin API and extension marketplace. Stay tuned.

### Why This Architecture?

**VoxCore stays lightweight:**
- Stateless, fast, predictable core
- No forced ML dependencies
- Quick startup, minimal memory

**Plugins add intelligence:**
- Opt-in enhancement (install what you need)
- Independent development and updates
- Community contributions welcome

**You choose your stack:**
- Fast-only: Just VoxCore
- Fast + smart: VoxCore + VoxCompose
- Fast + custom: VoxCore + your plugin

## License

MIT — see [LICENSE](LICENSE)

---

**Fast. Private. Secure. Yours.**

Your voice never leaves your Mac. Your recordings are yours forever.

Built for people who value speed, privacy, and control.
