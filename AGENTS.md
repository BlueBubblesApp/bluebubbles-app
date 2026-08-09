# Agent Instructions

This repo's knowledge base lives in `CLAUDE.md` files, not here.

Start at the root [`CLAUDE.md`](CLAUDE.md) for project orientation, then follow its
directory-specific pointers (e.g. `lib/CLAUDE.md`, `android/CLAUDE.md`, `windows/CLAUDE.md`, `linux/CLAUDE.md`) based on
what part of the codebase you're touching. Many subdirectories under `lib/` have their own
`CLAUDE.md` as well — check for one in the target directory before making changes.

For coding standards and conventions, read [`.claude/CLAUDE.md`](.claude/CLAUDE.md) and the
rule files it links to in [`.claude/rules/`](.claude/rules/) (frontend, api, database,
services, git).

For architecture and design rationale, see `docs/ARCHITECTURE.md` and `docs/DECISIONS.md`.

Treat all of the above as authoritative — this file exists only to route you there.

## Keep CLAUDE.md files in sync

Whenever you update code in a directory that has a `CLAUDE.md`, update that `CLAUDE.md` too if
the change makes it stale — typically when you add, remove, or rename files, or change a large
portion of the directory's functionality. Don't update it for small, self-contained edits that
don't change the directory's shape or behavior.
