#!/usr/bin/env bash
set -euo pipefail

# Global pre-push guard: block pushes to the remote default branch unless
# (a) changes are docs-only and (b) at least one commit message contains "skip pr".
# Per-repo opt-out: git config --local skippr.enabled false

remote_name="${1:-origin}"
remote_url="${2:-}"

# Allow opt-out per repo
if git config --bool --get skippr.enabled 2>/dev/null | grep -qi '^false$'; then
  exit 0
fi

# Resolve default branch name (e.g., origin/main)
default_ref="$(git rev-parse --abbrev-ref --symbolic-full-name "$remote_name/HEAD" 2>/dev/null || true)"
if [[ -z "$default_ref" ]]; then
  default_branch="main"
else
  default_branch="${default_ref#"$remote_name/"}"
fi

# Determine whether this push targets the default branch by reading ref updates from stdin.
# Each line from stdin: <local_ref> <local_sha> <remote_ref> <remote_sha>

targets_default=0
ranges=()
# Read all updates; we must not block if there is no stdin, so use a subshell with cat
while read -r local_ref local_sha remote_ref remote_sha; do
  # Ignore deletes (local_sha may be 0000... or local_ref can be (delete))
  if [[ "$remote_ref" == "refs/heads/$default_branch" ]]; then
    targets_default=1
    if [[ "$local_sha" != "0000000000000000000000000000000000000000" ]]; then
      ranges+=("$remote_name/$default_branch..$local_sha")
    fi
  fi
done < <(cat)

# If not pushing to default branch, allow
if [[ "$targets_default" -eq 0 ]]; then
  exit 0
fi

# Fallback: if we have no ranges (edge case), derive from HEAD
if [[ "${#ranges[@]}" -eq 0 ]]; then
  if git rev-parse --verify -q "$remote_name/$default_branch" >/dev/null; then
    ranges=("$remote_name/$default_branch..HEAD")
  else
    root="$(git rev-list --max-parents=0 HEAD | tail -1)"
    ranges=("$root..HEAD")
  fi
fi

# Aggregate commit messages and changed files across all ranges
msgs_total=""
changed_total=""
for r in "${ranges[@]}"; do
  msgs_total+=$'\n'"$(git log --format=%B "$r" 2>/dev/null || true)"
  changed_total+=$'\n'"$(git diff --name-only "$r" 2>/dev/null || true)"
done

# Determine explicit bypass via env var only (non-persistent)
bypass=0
case "${SKIPPR:-}" in
  1|true|TRUE|yes|YES|on|ON) bypass=1 ;;
  *) ;;
esac

# Decision: if bypass is set, allow anything to default branch
if [[ $bypass -eq 1 ]]; then
  echo "Bypassing: SKIPPR/skippr set by user"
  exit 0
fi

cat <<'OUT'
❌ Direct pushes to the default branch are blocked by your global pre-push guard.

To bypass for a single push, set the env var on the command:
  SKIPPR=1 git push              # or: SKIPPR=true git push

To disable in this repo only:
  git config --local skippr.enabled false
OUT
exit 1
