# Release Process

For the complete release guide including Homebrew formula updates, see [RELEASE_GUIDE.md](../../RELEASE_GUIDE.md) in the repository root.

## Quick Reference

**Tag and release:**
```bash
git push origin main  # Ensure commits are pushed
git tag -a v0.5.0 -m "Release 0.5.0"
git push origin v0.5.0
# Wait for GitHub Actions to create release
```

**Update Homebrew formula:**
```bash
cd ~/code/homebrew-tap
# Edit Formula/voxcore.rb with new version + SHA256
git commit -am "voxcore: update to v0.5.0"
git push origin main
```

For detailed instructions, troubleshooting, and the complete workflow, see [RELEASE_GUIDE.md](../../RELEASE_GUIDE.md).
