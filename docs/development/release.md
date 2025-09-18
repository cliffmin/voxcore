# Release Process

This document describes how to protect `main`, cut a release, and publish artifacts.

## Branch Protection (Production Rule Set)

For `main`, enable:

- Restrict creations: enabled
- Restrict updates: enabled
- Restrict deletions: enabled
- Require linear history: enabled
- Require a pull request before merging: enabled
  - Dismiss stale approvals on new commits: enabled
  - Require review from Code Owners: enabled (if using CODEOWNERS)
  - Require approval of the most recent reviewable push: enabled
  - Require conversation resolution before merging: enabled
- Require status checks to pass: enabled
  - Require branches to be up to date: enabled
  - Required checks: Java Tests; Lua & Shell Tests; Quality Checks
- Block force pushes: enabled
- (Optional) Require signed commits: off unless your workflow supports it

Notes:
- If you don’t see “enforce for admins,” use “Restrict updates” and “Restrict creations/deletions” and PR-only merges as equivalently strict enforcement.
- Consider tag protection rules for `refs/tags/v*`: block force pushes and deletions.

## Release Checklist

1. Version bump (e.g., 0.4.0)
   - Update Gradle `version` and CLI `@Command(version = ...)` banner
2. Merge `feature/*` → `main` via PR (passing required checks)
3. Tag and GitHub Release
   - `git tag v0.4.0 && git push --tags`
   - Create a GitHub Release and attach artifact bundle
4. CI artifacts
   - CI builds `dist/whisper-post.jar` and release tar bundle
5. Smoke checks post-release
   - `curl http://127.0.0.1:8765/health`
   - `curl -s -X POST http://127.0.0.1:8765/transcribe -H 'Content-Type: application/json' -d '{"path":"/abs/path.wav"}'`
   - `curl http://127.0.0.1:8765/metrics` (Prometheus)

## Notes on WS streaming

- `/ws` is experimental in 0.4.0: streams incremental pipeline output `{ processed: "..." }`.
- HTTP `/transcribe` is stable.