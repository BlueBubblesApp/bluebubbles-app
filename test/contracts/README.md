# Contract tests

Executable enforcement for [`ENGINEERING-STANDARDS.md`](../../ENGINEERING-STANDARDS.md).
These are **source sweeps** — they read every `.dart` file under `lib/` and assert
structural properties. They never execute application code, so they need no
device, no `.env`, and no Flutter asset bundle, and the suite runs in ~1s.

```bash
dart test test/contracts              # the gate (runs in CI on every PR)
dart run tool/contracts_report.dart   # the worklist — prints violations, never fails
```

Use `dart test`, not `flutter test` — these import only `dart:io`, `test`, and
`analyzer`, and `flutter test` would additionally demand the `.env` asset.

## Files

| File | Purpose |
| --- | --- |
| `source_sweep.dart` | Walks `lib/`, strips comments/strings, formats failures, `expectAtMostRatchet` |
| `ast_sweep.dart` | Dart AST visitors for the structural rules |
| `complexity_contract_test.dart` | §1–§2: scans in loops, N+1 queries, sorts in `build()` |
| `database_contract_test.dart` | §4: query lifecycle, `@Transient`, platform guards |
| `architecture_contract_test.dart` | §3, §5: layering, wrappers, theming, hygiene |
| `security_contract_test.dart` | §9: path traversal, secret leakage, Android surface |

## Adding a contract

1. **Find a real defect first.** Contracts are written after a bug is found and
   fixed, never speculatively.
2. Write the sweep — AST when the rule is structural, regex when it's a banned
   identifier.
3. **Measure the current tree** with `tool/contracts_report.dart`. If it isn't
   already zero, either fix the violations or set a ratchet ceiling and document
   what's left.
4. **Verify it fails.** Inject a violation, confirm it's caught, revert. A contract
   that cannot fail is worse than none.

## Ratchets

Rules the codebase doesn't satisfy repo-wide use `expectAtMostRatchet`, which fails
in **both** directions:

- Count went **up** → you added a violation. Fix it; don't raise the ceiling.
- Count went **down** → you fixed some. Lower the ceiling in the same commit, or the
  recorded floor goes stale and stops meaning anything.

## Allowlists

An exemption is an allowlist entry **with a written reason**, never a deleted rule.
A key ending in `/` exempts a directory subtree (used for vendored forks of upstream
Flutter widgets); anything else must match a path exactly.
