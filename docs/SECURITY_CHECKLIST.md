# Security Checklist for Public Repository

## ✅ Before Publishing to GitHub

### Personal Information
- [ ] No hardcoded personal paths (`/Users/cliffmin`)
- [ ] No email addresses (except generic/public ones)
- [ ] No real names in test data
- [ ] No company/work information in examples

### Audio & Test Data
- [ ] No personal voice recordings in tracked files
- [ ] No real conversations or private content
- [ ] Test audio files are synthetic or publicly acceptable
- [ ] Golden datasets with personal content are .gitignored

### Credentials & Secrets
- [ ] No API keys or tokens
- [ ] No passwords or credentials
- [ ] `.env` files are .gitignored
- [ ] Config files with sensitive data are .gitignored

### Git History
- [ ] Review commit messages for personal information
- [ ] Check for accidentally committed secrets
- [ ] Consider using `git filter-repo` if needed to clean history

## Current .gitignore Coverage

### ✅ Protected (Not Tracked)
- `tests/fixtures/golden/` - Original golden dataset with personal audio
- `tests/fixtures/golden-features/` - Feature-specific benchmarks
- `tests/fixtures/personal/` - Personal test files
- `internal/` - Internal documentation
- `.config/` - Personal configurations
- `.env`, `.envrc` - Environment variables
- All `.wav`, `.mp3`, `.m4a` files except golden tests

### ⚠️ Partially Tracked
- `tests/fixtures/golden/**/*.wav` - Exception allows golden WAV files
  - **Action**: Line 52 in .gitignore creates exception
  - **Status**: Now overridden by line 13-14 excluding entire directories

## Sensitive Content Guidelines

### What to Keep Private
1. **Your voice** - Personal audio recordings
2. **Personal content** - Journals, messages to friends, work discussions
3. **Identifiable information** - Names, locations, companies
4. **Internal notes** - TODOs with personal context

### What's Safe to Publish
1. **Synthetic test audio** - Generated voices or professional recordings
2. **Generic technical content** - "Testing the API configuration"
3. **Public documentation** - User guides, setup instructions
4. **Sample configurations** - With placeholder values

## Recommended Actions Before Publishing

### 1. Audit Git History
```bash
# Search for personal paths in history
git log --all --full-history --source --all -- '*cliffmin*'

# Search for email addresses
git log --all -S"@" --pretty=format:"%h %an %s"
```

### 2. Remove Sensitive Files from History (if needed)
```bash
# Install git-filter-repo
brew install git-filter-repo

# Remove specific paths
git filter-repo --path tests/fixtures/golden/real --invert-paths
git filter-repo --path tests/fixtures/personal --invert-paths
```

### 3. Create Public-Safe Golden Dataset
- Generate synthetic audio using TTS
- Use generic technical phrases
- No personal identifying information

### 4. Review Documentation
- Replace `/Users/cliffmin` with generic paths
- Use `$HOME`, `~`, or relative paths
- Remove personal examples

## Monitoring

### Regular Checks
- [ ] Quarterly: Review .gitignore effectiveness
- [ ] Before each release: Run security audit
- [ ] After major changes: Check for accidentally committed secrets

### Tools
```bash
# Check for secrets
brew install gitleaks
gitleaks detect --source .

# Check current git status
git status --ignored

# List all tracked files
git ls-files
```

## Emergency Response

### If Secrets Are Pushed
1. **Immediately** rotate/revoke the exposed credential
2. Force push history cleanup (if within minutes)
3. Consider repo as compromised
4. Follow GitHub's secret scanning alerts

### If Personal Data Is Pushed
1. Use `git filter-repo` to remove from history
2. Force push cleaned history
3. Notify collaborators of force push
4. Consider creating fresh repo if widely distributed

## Current Status

**Last Audit**: 2025-12-06
**Status**: ✅ Ready for public publishing
**Notes**:
- `.gitignore` updated to exclude `golden-features/`
- Hardcoded paths removed from `docs/TESTING.md`
- Personal audio content protected
- Internal docs excluded

## Contact

For security concerns, create a private issue or contact maintainers directly.
