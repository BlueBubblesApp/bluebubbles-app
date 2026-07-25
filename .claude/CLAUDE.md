# Claude Workflow — BlueBubbles

## Rules
Detailed coding standards live in `.claude/rules/`:
- `frontend.md` — widget patterns, state, theming, naming
- `api.md` — HTTP calls, interface→action pattern, error handling
- `database.md` — ObjectBox entities, queries, transactions, serialization
- `services.md` — service access, event dispatch, method channels, navigation
- `git.md` — commit message format

## Engineering Standards (enforced)

`ENGINEERING-STANDARDS.md` is the performance and code-quality bar. Unlike the
rule files above, its rules are **executable**: `test/contracts/` enforces them
and runs in CI on every PR. Read §6 for what's locked at zero vs. ratcheted, and
§8 for what is deliberately *not* enforced (notably: no runtime perf measurement,
no behavioral tests).

```bash
dart test test/contracts              # the gate
dart run tool/contracts_report.dart   # the worklist
```

Before optimizing anything, read §0 — especially §0.3, "validate the ruler."

## Architecture & Design Decisions
- `docs/ARCHITECTURE.md` — how the system's major subsystems work and interact
- `docs/DECISIONS.md` — why key design choices were made (isolate pattern, GetIt vs GetX, ChatState, etc.)
- `docs/COMMON_TASKS.md` — step-by-step recipes for frequent development tasks
- `docs/MESSAGE_RECEIVE_FLOW.md` — end-to-end trace: socket → queue → DB → state → UI
- `docs/MESSAGE_SEND_FLOW.md` — end-to-end trace: send button → tempGuid → HTTP + socket race → real GUID swap
- `docs/MODELS.md` — reference for the DB entity / DTO model landscape (`lib/database/`, `lib/models/`)
- `docs/THEMING_AND_COMPONENTS.md` — reusable `BBScaffold`/`BBAppBar`/`BBChip`/dialog wrappers, skin vs. theme mechanics, color access patterns

## Before Making Changes
- Check for `CLAUDE.md` in the target directory
- Read root `CLAUDE.md` for architecture orientation
- For non-trivial tasks, read `docs/ARCHITECTURE.md` and the relevant section of `docs/DECISIONS.md`
- Load the relevant rule file(s) from `.claude/rules/` before writing code

## Code Generation
After editing `@Entity` classes in `lib/database/io/`:
→ `dart run build_runner build`
→ Never edit `lib/generated/objectbox.g.dart` directly

## Lint / Style
- `bash scripts/dart-fix-common-issues.sh` — runs `dart fix --apply` for common issues
- Line length: 120 chars

## Testing

- `dart test test/contracts` — the contract suite (source sweeps enforcing
  `ENGINEERING-STANDARDS.md`). Runs in ~1s. **Must pass before every commit.**
- **No unit, widget, or integration tests yet.** The contracts never execute
  application code, so behavioral changes still have to be verified by running
  the target platform. See standards §8.2 for the first targets worth testing.

## Branches
Branch off `master`; PRs target `master`.

CI (`.github/workflows/`): `pr-check.yml` runs `flutter analyze`
(`--no-fatal-infos` — there is a legacy baseline of ~302 info-level lints, so
only new warnings/errors fail), the contract suite, and an unsigned Windows +
Linux compile. `desktop-builds.yml` handles signing/packaging on tags.
