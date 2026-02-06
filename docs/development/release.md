# Releases

## How to Install / Upgrade

```bash
# First time
brew tap cliffmin/tap
brew install voxcore
voxcore-install

# Upgrade
brew update && brew upgrade voxcore && voxcore-install
```

Reload Hammerspoon after upgrading (menubar -> "Reload Config" or Cmd+Opt+Ctrl+R).

**Optional:** Add [VoxCompose](https://github.com/cliffmin/voxcompose) for ML-powered transcript refinement:

```bash
brew install voxcompose ollama
ollama serve &
ollama pull llama3.1
```

## How Releases Are Built

Releases follow [Semantic Versioning](versioning.md). The process:

1. Version is bumped in `whisper-post-processor/build.gradle`
2. Changes are documented in [CHANGELOG.md](../../CHANGELOG.md)
3. A git tag (e.g., `v0.6.1`) triggers CI to build the release
4. The Homebrew formula in [homebrew-tap](https://github.com/cliffmin/homebrew-tap) is updated with the new URL and SHA256

VoxCore and VoxCompose version independently. VoxCore is always released first when both have updates.

## What Gets Updated

| Component | Updated By |
|-----------|-----------|
| Java post-processor JAR | `brew upgrade voxcore` |
| Hammerspoon Lua scripts | `voxcore-install` (re-symlinks) |
| User config (`ptt_config.lua`) | Never overwritten |
| Voice recordings | Never touched |

## Release History

See [CHANGELOG.md](../../CHANGELOG.md) for the full release history.

**Current versions:** VoxCore v0.6.1, VoxCompose v1.0.0

## Troubleshooting

**Formula not found:** `brew update && brew tap cliffmin/tap`

**SHA256 mismatch:** `brew uninstall voxcore && brew cleanup && brew install voxcore`

**Old scripts after upgrade:** Run `voxcore-install` to re-symlink latest Lua scripts.
