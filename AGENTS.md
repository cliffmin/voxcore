# Global AI Agent Guidelines for VoxCore

**All AI agents working on this codebase must follow these guidelines.**

## Non-Negotiable Rules

### G0: Read Repository Context First
- **Always** read `README.md` before writing code
- Check `CONTRIBUTING.md` for commit message format
- Review `docs/development/architecture.md` for system design
- Check `internal/docs/repo-practices.md` for project conventions
- If working in a specific directory, check for directory-specific `AGENTS.md` files

### G1: Ask When Uncertain
- If unsure about project-specific behavior, **ask the developer** before making changes
- Don't assume project conventions match general best practices
- Clarify requirements for ambiguous requests

### G2: Follow Project Structure
- **Core PTT functionality**: `hammerspoon/` (Lua) or `whisper-post-processor/` (Java)
- **Setup/utilities**: `scripts/`
- **Tests**: With code (Java) or `tests/` (integration)
- **Documentation**: `docs/` (public) or `internal/docs/` (internal)
- **Internal analysis**: `internal/` (gitignored)

### G3: Stay in Context
- Stay within the current task context
- Inform developer if it'd be better to start afresh or create a separate task
- Don't refactor unrelated code "while you're at it"

### G4: Preserve Patterns
- Follow existing code patterns over creating new abstractions
- Reuse existing modules before adding dependencies
- Maintain consistency with codebase style

### G5: Direct Modifications
- Directly modify existing code rather than duplicating or creating temporary versions
- Delete unused code completely (no backwards-compat hacks)
- Clean up after refactoring

## Development Philosophy

1. **Simplicity**: Prioritize clear, maintainable solutions; minimize unnecessary complexity
2. **Pattern Consistency**: Follow established patterns and architectural designs; propose alternatives only with clear justification
3. **Stateless Core**: Keep core algorithmic and stateless (see architecture.md)
4. **Plugin Architecture**: Advanced/ML features go in plugins, not core
5. **Testing**: Add tests for new behavior; run existing tests before committing
6. **Documentation**: Update user docs, API docs, and CHANGELOG for user-visible changes

## Git Workflow

See `.cursor/rules/git-workflow.mdc` for detailed git policies. Summary:

- **Default**: Stage changes only, wait for user review
- **Commits**: Use area prefixes (`ptt:`, `ui:`, `docs:`, etc.) - see CONTRIBUTING.md
- **Never push** without explicit "push" or "ship it" command
- **No emoji** or meta-comments in commit messages

## Quality Checklist

Before considering work complete:

- [ ] Tests pass (`make test` or `make test-java-all`)
- [ ] No personal data or audio checked in
- [ ] Documentation updated (user docs, API docs, CHANGELOG if user-visible)
- [ ] Backwards compatible or has migration notes
- [ ] Reuses existing patterns; avoids duplication
- [ ] Follows project structure (files in correct directories)

## Decision Framework

- **SIMPLE** (< 3 files, obvious): Just do it
- **COMPLEX** (architectural, multiple approaches): Present plan, wait for approval
- **UNCERTAIN**: Ask for clarification

See `.cursor/rules/decision-framework.mdc` for details.

---

**Note**: These rules are enforced via Cursor's `.cursor/rules/*.mdc` files. This `AGENTS.md` serves as a human-readable summary and reference.

