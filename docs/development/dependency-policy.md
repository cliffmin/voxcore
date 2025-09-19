# Dependency Version Policy

This project uses a Gradle Version Catalog to pin and manage dependency versions for the Java post-processor.

Scope (current)
- Module: whisper-post-processor
- Catalog file: whisper-post-processor/gradle/libs.versions.toml
- Build script references: whisper-post-processor/build.gradle via libs aliases (e.g., libs.gson, libs.junitJupiter)

Rationale
- Single source of truth for dependency versions
- Easier upgrades and conflict resolution
- Cleaner build.gradle with readable aliases

Upgrade process
1) Edit whisper-post-processor/gradle/libs.versions.toml
   - Bump versions under [versions]
2) Validate locally
   - ./whisper-post-processor/gradlew -p whisper-post-processor test --no-daemon --console=plain
3) Open PR
   - Title: build(whisper-post-processor): bump <dep> to <version>
   - Include brief notes on changes and links to release notes if relevant

Notes
- Plugins: The shadow plugin version is currently declared in build.gradle to minimize blast radius. We may migrate plugin versions into the catalog later using [plugins] aliases.
- CI: No changes required; tests must remain green.
- Dependabot: Gradle version catalogs are supported; automated PRs may target libs.versions.toml entries.

Troubleshooting
- If a library adds transitive changes that break tests, consider bumping related test/runtime dependencies together (e.g., JUnit Platform + Jupiter, AssertJ + Mockito).
- Keep AssertJ, JUnit Jupiter, and JUnit Platform in compatible ranges (see their release notes).
