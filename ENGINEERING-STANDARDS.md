# Engineering Standards — BlueBubbles

> **Prime directive: when a contract test fails, fix the SOURCE, not the test.**
> A ceiling in §6 may only ever move down. Weakening a contract to make code
> pass inverts the entire system.

**A standard that isn't executable is a suggestion.** This document's rules are
enforced by the contract suite below, which runs in ~1 second and is wired into
`.github/workflows/pr-check.yml`:

| Contract | File |
| --- | --- |
| Complexity & algorithms (§1, §2) | `test/contracts/complexity_contract_test.dart` |
| ObjectBox rules (§4) | `test/contracts/database_contract_test.dart` |
| Layering, wrappers, hygiene (§3, §5) | `test/contracts/architecture_contract_test.dart` |
| Security invariants (§9) | `test/contracts/security_contract_test.dart` |
| Shared text-sweep machinery | `test/contracts/source_sweep.dart` |
| Shared AST-sweep machinery | `test/contracts/ast_sweep.dart` |
| Triage worklist (non-failing) | `tool/contracts_report.dart` |

```bash
dart test test/contracts          # the gate
dart run tool/contracts_report.dart   # the worklist
```

**§8 is not an appendix.** It lists what these standards do *not* yet enforce —
most importantly that this project has **no runtime performance measurement at
all**. Read it before claiming anything here is "verified."

**§9.6 is an open, unresolved security risk** — blanket TLS certificate trust for
the configured server host. It needs a product decision. Read it before assuming
the transport is secure.

---

## 0. Method — how every other rule is derived

Everything below §0 is a *conclusion*. This is the method that produced them and
the method every future change must use.

**Reason from the platform, never from the convention.** The default engineering
move is analogy: "this is how Flutter apps do it." Analogy imports other
people's constraints along with their solution. Ask instead what is *actually*
true here: the 16.6ms frame budget at 60Hz (8.3ms at 120), the real cost of an
ObjectBox query handle, what `Obx` actually subscribes to, how many messages a
five-year iMessage history really holds. A "best practice" is a cached answer to
someone else's question — verify it still holds for ours.

### 0.1 "Impossible" is a measurement you haven't taken

Treat *impossible* as a bug report against your own understanding. Almost every
"can't be done" is one of three things in disguise: **unmeasured** (nobody
profiled it), **an unquestioned requirement** (the expensive thing shouldn't
exist), or **expensive but not impossible** (it costs something, and the real
decision is whether the win is worth the price, stated honestly).

Genuine walls exist — ObjectBox cannot express "newest 1 row per group" as a
single query, and that is why §2.3 has an allowlist rather than a zero. But you
must *prove* you've hit one, naming the specific limitation, before accepting it.

### 0.2 The algorithm (apply strictly in order)

1. **Question the requirement.** Every requirement carries a person's name, not a
   department, so it can be challenged. Requirements from senior sources are the
   *most* dangerous because they get questioned least.
2. **Delete the part.** The best code is no code. `sync_helpers.dart` — 218
   lines, 95 already commented out, containing the three worst algorithms in the
   repo — was deleted in this pass because nothing called it. A deleted file
   can't have a bug, a maintenance cost, or a contract test.
3. **Simplify / optimize — but only what survived step 2.** This is where §1–§4
   live. They come *third*. Optimizing code that shouldn't exist is the most
   invisible waste in software.
4. **Accelerate the loop.** `dart test test/contracts` runs in ~1s. A fast
   idea→verdict loop is what makes aggressive change affordable rather than
   reckless.
5. **Automate — last.** Only automate a rule already proven correct. The
   contracts in §6 were written *after* each defect was found and fixed by hand,
   never speculatively.

### 0.3 Validate the ruler before you trust the number (mandatory)

A wrong measurement is worse than none: no data leaves you knowing you're
ignorant, bad data leaves you confidently wrong. This has already cost this repo a
full audit — `dart analyze` reported 46,504 errors, every one phantom, because the
installed SDK predated `pubspec.yaml`'s minimum and no dependency had resolved.
The real baseline was 302 info-level lints and zero errors.

1. **Prove the instrument before reporting a number.** Here: `dart analyze` is
   meaningless unless `.dart_tool/package_config.json` exists and the SDK
   satisfies `pubspec.yaml`. A five-second check.
2. **A number that disagrees sharply with a trusted signal is a measurement bug
   until proven otherwise.** CI is green on every PR; local said 46,504 errors.
   Those can't both describe the same tree — reconcile the instruments first.
3. **State the subject with every number.** "302 issues" is meaningless; "302,
   all info-level, `dart analyze lib`, Dart 3.12.2, deps resolved" is falsifiable.
4. **This generalizes** to anything that can silently point at the wrong target:
   a stale `objectbox.g.dart` after an entity edit, a contract whose regex never
   matches, `flutter test` failing on a missing `.env` and being read as "tests
   are broken."

**Corollary: a contract that cannot fail is worse than no contract.** Verify a new
contract in *both* directions — it passes clean, and it actually fails on an
injected violation. Two contracts here were born broken: one flagged correct code
(a text window couldn't tell a loop body from a callback), and one could never
match because it searched text its own comment-stripper had blanked.

### 0.4 Novelty is mandatory, and earns its place by measurement

Reach for the best algorithm or structure available — or one that doesn't exist
yet — not the familiar one. But nothing ships on "should work": a novel approach
ships only when a measurement shows it beats the incumbent on the metric that
matters, and a novel approach that doesn't beat the baseline is **deleted and
recorded** so nobody re-derives the same dead end.

That record — the measured-and-rejected ledger — is a first-class artifact. It
lives in §8.4. It should grow.

---

## 1. The complexity doctrine

"Everything O(1)" is not a coherent goal: sorting has an O(n log n) lower bound,
rendering n messages produces n widgets, and a full sync must touch every row.
The achievable standard:

1. **Per-frame work is O(1).** A scroll tick, a rebuild, or an incoming receipt
   does constant work in the number of *stored* messages and chats. Not constant
   work in the number of *visible* items — that's inherent — but nothing may
   scale with the database.
2. **Per-build work is O(1) per changed thing.** `build()` reads precomputed
   fields and `Map` lookups. No build path sorts, filters, parses, or queries.
3. **Linear and worse work runs exactly once**, where the data changes — in a
   service, an action, or a cached field — never per rebuild and never per
   element of an enclosing loop.
4. **Where linear-per-event is inherent, use the optimal structure.** The chat
   list must stay ordered, so `ChatsService` maintains it by binary-search
   insertion (O(log n) to locate, O(n) memmove) rather than re-sorting O(n log n)
   on every access. `ChatMessages` is five hash maps, not a list, so message,
   reaction, attachment, thread, and edit lookups are all O(1).
5. **O(1) says nothing about the constant.** A handler can be algorithmically
   O(1) and still blow the frame budget by rebuilding a whole screen, allocating
   a list copy per access, or doing a synchronous DB read on the UI isolate.
   Items 1–4 bound the *shape* of the work; only measurement bounds its
   *duration* — and see §8.1, because this project cannot currently measure that
   at all.

When you cannot make something O(1), the required move is to state *why* — naming
the lower bound or platform limitation — in a comment at the site, and to run it
at the lowest frequency possible.

---

## 2. Algorithms & data structures

### 2.1 Lookups are hash lookups, never scans

*Enforced: `complexity_contract_test.dart` — no `.toList().contains(...)`.*

*Origin: `ReactionTypes.toList().contains(...)` at 10 sites, several inside
`.where()` predicates on the per-message render path — a fresh list allocated and
scanned per message part, per rebuild.*

```dart
// ✅ built once at compile time, O(1) per test
static const Set<String> all = {LOVE, LIKE, DISLIKE, LAUGH, EMPHASIZE, QUESTION};
if (ReactionTypes.all.contains(type)) ...

// ❌ allocates + scans on every single call
if (ReactionTypes.toList().contains(type)) ...
```

Keep an ordered `List` only for UI that renders in order (the reaction picker);
membership tests use the `Set`.

### 2.2 No linear scan inside a loop over another collection

*Enforced: `complexity_contract_test.dart` — AST sweep, ratchet at 5.*

*Origin: four O(n·m) sites, the worst being `database.dart`'s v2 migration, which
scanned every handle for every message — hundreds of millions of comparisons
before the app opens.*

Build the index once, outside the loop:

```dart
// ✅
final byGuid = {for (final m in batch) if (m.guid != null) m.guid!: m};
for (final m in batch) { final target = byGuid[m.associatedMessageGuid]; ... }

// ❌ O(n*m)
for (final m in batch) {
  final target = batch.firstWhereOrNull((e) => e.guid == m.associatedMessageGuid);
}
```

The ratchet's 5 remaining sites are all bounded by a small n that *cannot grow
with the database* — participants in one group chat, parts of one message, the
user's current selection. That distinction is the rule: O(small) is fine,
O(rows) is not.

### 2.3 No N+1 database query

*Enforced: `complexity_contract_test.dart` — AST sweep, ratchet at 13.*

*Origin: `CustomGroupActions` ran one `guid.equals()` query per guid — 50 chats
meant 50 queries — and leaked every one.*

```dart
// ✅ one query, then an O(1) index
final query = Database.chats.query(Chat_.guid.oneOf(guids.toList())).build();
try { return query.find(); } finally { query.close(); }

// ❌ N queries, N leaked handles
guids.map((g) => Database.chats.query(Chat_.guid.equals(g)).build().findFirst())
```

Paginated sync is allowlisted: one query per *page* is the pagination, not an
N+1 over rows. The per-chat latest-message lookup is allowlisted for a real
platform limit — ObjectBox has no "newest 1 row per group". The contract's
allowlist carries the reason for each; the ceiling comment names which of the 13
are genuinely fixable, so it reads as a worklist rather than a number.

### 2.4 One fused pass, not a chain of filters

*Origin: `getFilteredChats` chained seven `.where(...).toList()` passes — a full
copy of the chat list each — inside the conversation list's `Obx`.*

One `.where()` with a fused predicate and one `.toList()`. **But see §3.7:**
fusing filters changes which fields get read, and when those reads are
reactive, that silently changes the widget's subscriptions. That is the subtle
part, and it has its own rule.

### 2.5 Don't sort to get one element

*Origin: `_recomputeDeliveredIndicators` sorted every outgoing message per load
and per receipt, then only ever max-scanned it. The `mostRecent*` getters copied
and sorted the whole list to take `firstOrNull`.*

A single linear pass answers "the newest one" in O(n), not O(n log n). When you
remove a sort that was *accidentally* providing a tie-break, replace the
tie-break explicitly — `MessagesService._sortsBefore` exists for exactly that,
so behavior on equal timestamps is preserved rather than silently changed.

### 2.6 Views over copies on read-only paths

*Origin: `ChatMessages.messages` returned a full copy per access, and hot paths
called it per receipt and per load.*

Callers that *store* the result need an independent list they can sort. Callers
that only iterate or scan should not pay for a copy. Hence two accessors:
`messages` (copy, documented as such) and `messagesView` (lazy `Iterable`, no
copy). A lazy view must not be held across a mutation — it reflects later
`addMessages`/`removeMessage` calls and throws if the map changes mid-iteration.
Verify before swapping one in: this pass checked all six swapped loops for struct
mutation before changing them.

---

## 3. Flutter build & reactivity law

### 3.1 `Obx` wraps the smallest subtree that reads a reactive value

Wrapping a whole screen makes every observable in it a rebuild trigger for all
of it. Nest a second `Obx` for an inner subtree reading a different set.

### 3.2 Never read `.value` outside `Obx`/`GetBuilder`

You get the value once and no updates. This is a silent staleness bug, not an
error.

### 3.3 Cache expensive derivations in `_cached*` fields

Populate in `initState()`, refresh in `didUpdateWidget()` when the relevant props
change, read from cache in `build()`. Never recompute inline — colors, initials,
and avatar paths are the established cases.

### 3.4 `build()` never sorts, filters, parses, or queries

*Enforced: `complexity_contract_test.dart` — AST sweep, ratchet at 2.*

The two remaining sites are in `preset_theme_strip.dart`, a settings panel
deriving Material-You theme collections per build. Real, but off the messaging
hot path; the fix is to derive them once in the controller.

The contract deliberately flags only `build()`'s own statements, not closures
inside it, because a text-level rule could not tell an `Obx(() => ...)` builder
(per-frame — a real violation) from an `onPressed:` (per user action — fine), and
guessing wrong in the noisy direction is what gets contracts ignored (§0.3).
Reviewers still need to catch per-frame builders by eye.

### 3.5 Widgets never write state directly

Service-driven mutations go through `updateXxxInternal()` on `ChatState` /
`MessageState`. Widgets **read** state; `ChatsService` / `MessagesService`
**write** it. This is what keeps derived booleans (`hasError`, `isSent`) in sync
with the fields they depend on — they're updated in the same method.

### 3.6 Equality-check before assigning to an observable

`if (field.value != value) field.value = value;` — an unconditional assignment
notifies every listener even when nothing changed, which is a rebuild storm on a
busy socket.

### 3.7 A refactor must preserve the set of reactive reads

**Origin, and the subtlest lesson in this document.** Fusing
`getFilteredChats`'s filter chain into one predicate looked purely mechanical. It
wasn't: the old chain applied dimensions in a fixed order, each pass operating on
the previous pass's survivors, so a chat rejected by the archived filter *never
had its `hasUnreadMessage.value` read*. `Obx` builds its subscription set from
exactly which observables get read during the build. Reordering the fused
predicate — or short-circuiting differently — would have quietly changed which
chats the conversation list is subscribed to, producing a list that stops
updating for some chats. Not a crash, not a test failure: a stale UI.

The fix was to keep the predicate's condition order identical to the old chain's
application order, so `&&` short-circuiting reproduces the original read set
exactly, and to say so in a comment at the site. The same care applied to
`custom_group_filter_chip_row.dart`, where the unread-count rewrite kept reading
`hasUnreadMessage.value` for every chat state even though the new algorithm could
have skipped some.

**When you touch a reactive read path, ask what the subscription set was before
and after — not just what the return value is.**

### 3.8 Dispose everything

Cancel `StreamSubscription`s, timers, and listeners in `dispose()`. Check
`mounted` before `setState()` in any async callback or stream listener. Not
currently enforced by a contract — see §8.2.

---

## 4. Database law (ObjectBox)

### 4.1 Every built query is closed

*Enforced: `database_contract_test.dart` — zero tolerance.*

*Origin: 12 sites built a query and never closed it, two inside a per-guid loop.
`database.md` already required closing them; nothing enforced it, so it drifted.*

```dart
final query = box.query(...).build();
final List<T> rows;
try { rows = query.find(); } finally { query.close(); }
```

Chaining `.build().find()` makes closing *impossible* — the handle is never
named — which is why the contract bans that shape outright rather than trying to
prove a close exists.

### 4.2 Public `Rx*` fields on an `@Entity` are `@Transient()`

*Enforced: `database_contract_test.dart` — zero tolerance.*

A persisted observable would be serialized into the store. Private `_`-prefixed
backing fields behind a plain getter/setter pair are exempt and are the preferred
shape — `objectbox_generator` doesn't persist them, which is exactly why `Chat`
and `Message` are written that way. The first draft of this contract flagged all
7 of those as violations; scoping it to public fields was the fix, and it's a
reminder to check a new rule's hits before trusting its count.

### 4.3 Batch, transact, and stay off the UI isolate

- Batch with `Property.oneOf([...])`; see §2.3.
- `TxMode.read` for queries, `TxMode.write` for puts/removes. Never nest.
- Catch `UniqueViolationException` where duplicates are possible: log and
  continue, don't rethrow.
- `await runAsync(() => query.find())` for anything large — a synchronous read on
  the UI isolate is a dropped frame.
- Guard every `Database.*` path with `kIsWeb` (web has no ObjectBox), and never
  import a `database/io/` model from `database/html/` (*enforced*).

---

## 5. Architecture invariants

- **Interface → Action → Isolate.** Interfaces build a `Map<String, dynamic>` and
  route to the isolate; actions extract typed params, run the transaction, and
  return **primitive IDs**; the interface rehydrates from the DB. Never return an
  entity with lazy relations across an isolate boundary.
- **`GetIt` for services, GetX `Rx*` for UI state only.** Access via the
  shorthand getters in `lib/services/services.dart`.
- **`HttpService` is a thin entrypoint** (*enforced*, ratchet at 1). Domain
  endpoints live in `lib/services/network/api/<domain>_api.dart` and are reached
  via `HttpSvc.<domain>.<method>()`. Every request wraps `runApiGuarded()`,
  calls `buildQueryParams()`, and ends with `returnSuccessOrError()`.
- **`ChatState` / `MessageState` are what widgets read; the services write them.**
  See §3.5.
- **Navigate via `NavigationSvc`** (*enforced*, ratchet at 98), not
  `Navigator.of(context)`.
- **Use the `BB*` wrappers** — `BBScaffold`, `BBAppBar`, `BBChip`, the dialog
  helpers (*enforced*, ratchets at 9 and 2). They bake in this app's skin,
  theming, and platform conventions; a raw `Scaffold` silently opts out of all
  three.
- **Colors come from `context.theme`** (*enforced*, ratchet at 9). Dark-mode
  branches use `ThemeSvc.inDarkMode(context)`, never `MediaQuery` —
  `MediaQuery` reports the OS brightness and ignores the in-app
  light/dark/system override, so it disagrees with the theme actually rendered
  (*enforced*, zero tolerance).
- **Every barrel export resolves** (*enforced*, zero tolerance). Origin:
  `sync_helpers.dart` sat unreachable behind a live `helpers.dart` export for an
  unknown period. Dead code can't be reviewed, so it rots into a trap for the
  next person, who reasonably assumes it runs. Delete a file and its export in
  the same commit.
- **After editing an `@Entity`:** `dart run build_runner build`. Never hand-edit
  `lib/generated/objectbox.g.dart`.

---

## 6. The regression ratchet

1. **Every fix lands with a contract in the same commit.** A defect that recurs
   after being fixed once is a process failure, not bad luck.
2. **Sweeps over pins.** Contracts walk every source under `lib/` so they catch
   files that don't exist yet, not just today's known hot spots.
3. **Ceilings only go down.** Where the codebase doesn't satisfy a rule
   repo-wide, the contract records the measured count as a ratchet.
   `expectAtMostRatchet` fails if the count goes **up** (you added a violation)
   *and* if it goes **down** (you fixed some — lower the ceiling in the same
   commit so the progress is locked in and can't silently regress).
4. **Exemptions are allowlist entries with a written reason**, never a deleted
   rule. Directory-prefix entries exist for vendored upstream forks; everything
   else must match an exact path so an exemption can't widen to a sibling file.
5. **Verify a new contract in both directions** — passes clean, and actually
   fails on an injected violation (§0.3).

Current state, measured 2026-07-25 on Dart 3.12.2 with dependencies resolved:

| Rule | State |
| --- | --- |
| `.toList().contains(...)` | **0** — locked |
| `ReactionTypes.toList().contains` | **0** — locked |
| Unclosed ObjectBox query | **0** — locked |
| Public `Rx` on `@Entity` without `@Transient` | **0** — locked |
| `database/html/` importing `database/io/` | **0** — locked |
| `MediaQuery` brightness | **0** — locked |
| Broken barrel export | **0** — locked |
| Query built inside a loop | ratchet **13** (triaged in-contract) |
| Scan inside a loop | ratchet **5** (all O(small), was 8) |
| `.sort()` in `build()` | ratchet **2** |
| `dio` call in `HttpService` | ratchet **1** (documented exception) |
| `Navigator.of(context)` | ratchet **98** |
| Raw `Scaffold` / `AppBar` | ratchet **9** / **2** |
| Hardcoded `Color(0x…)` | ratchet **9** (+25 allowlisted vendored forks) |

`flutter analyze` baseline: **302 issues, all `info`-level, zero errors, zero
warnings.** CI runs `--no-fatal-infos`, so that legacy info baseline doesn't
block PRs but new warnings and errors do.

---

## 7. Naming and organization

Follow `.claude/rules/frontend.md` for widget naming
(`[Feature]Controller`, `[Model]State`, `_cached[Name]`,
`update[Field]Internal`). Beyond that:

- **Directory structure mirrors the domain, not the framework.** `lib/services/`
  splits by subsystem (`backend/`, `network/`, `ui/`, `isolates/`), not by
  Flutter concept.
- **Platform models split `io/` (native) / `html/` (web stub) / `global/`
  (shared).** Web is **deprecated** — don't design for it, but don't break its
  compile either.
- **Every exported name says what it does.** `messagesView` over `messages2`,
  `_sortsBefore` over `_cmp`.
- **Commits:** `<type>: <message>`, lowercase, no scope parens, no trailing
  period. `feat:` / `fix:` / `chore:` / `wip:`.

---

## 8. What these standards do NOT enforce

The honest gap list. Everything above is checkable; everything here is not, and
saying so is what keeps the rest credible.

### 8.1 There is no runtime performance measurement, at all

Every complexity rule in §1–§2 is **static**: it bounds the *shape* of the work,
never its duration. There is no frame-timing harness, no startup-time budget, and
no jank gate. So §1 item 5 — "O(1) says nothing about the constant" — is currently
**unenforceable**, and no claim in this document should be read as "this is
fast." The claims are "this is not accidentally quadratic."

Closing this is the single highest-value next step. Flutter's real bar is the
frame budget (16.6ms at 60Hz, 8.3ms at 120Hz); the tools are
`flutter run --profile` with DevTools' timeline, `--trace-startup`, and
`SchedulerBinding` frame callbacks. Until something automated exists, the honest
statement is: **unmeasured.**

### 8.2 No unit, widget, or integration tests

`test/contracts/` contains source sweeps only — it never executes a line of
`lib/`. There is no test that `getFilteredChats` returns the right chats, that
`_sortsBefore` breaks ties the way the old sort did, or that the fused predicate
preserves the `Obx` subscription set from §3.7. Those behavioral claims were
verified by reading, not by running. `Chat.sort`, `Message.sort`,
`ChatsService._findInsertionIndex`, and the `MessagePart` builders are pure
enough to unit-test today and are the obvious first targets.

Consequence worth stating plainly: **the fixes in this pass are analyzer-clean
and contract-clean, not behaviorally tested.** The app should be run before
these ship.

### 8.3 Rules that are ratcheted, not satisfied

The ratchets in §6 are real violations, not settled policy. `Navigator.of` at 98
sites and 34 hardcoded colors are mechanical cleanups nobody has done. A ratchet
stops the bleeding; it is not the same as compliance.

### 8.4 The measured-and-rejected ledger

A rejection is only final for the metric and the measurement that produced it.
Record both, so a future engineer can tell "impossible" from "didn't help *that*
number under *that* setup."

- **A shared `QueryBuilder.findAndClose()` extension** (2026-07-25). Considered
  for §4.1 to make the correct thing the shortest thing. **Rejected:** the
  natural home is the `helpers` barrel, which is web-safe and shared, and the
  extension would drag ObjectBox types into it — ObjectBox does not exist on
  web. Five call sites weren't worth a new platform-split file. Re-open if the
  count grows or if the web target is formally dropped.
- **A text-window "no `.sort()` in `build()`" rule** (2026-07-25).
  **Rejected on a false positive:** flagged a `.sort()` inside an `onPressed:`
  callback. Replaced by the AST implementation in `ast_sweep.dart`. The lesson
  generalizes to every structural rule — see §0.3.
- **`win32` 6.x, `share_plus` 13.x, `package_info_plus` 10.x,
  `network_info_plus` 8.x, `device_info_plus` 12.x/13.x** (2026-07-25).
  **Blocked upstream, not rejected on merit:** all of them require `win32 ^6`,
  and `file_picker` — 11.0.2 is the newest published version — still pins
  `win32: ^5.9.0`. Verified against the pub.dev API, not assumed. Re-check when
  `file_picker` publishes a release allowing `win32 6`; the constraint comments in
  `pubspec.yaml` record this at each pin.
- **`unifiedpush` 6.x.** Left at 5.x on a pre-existing in-repo note that v6
  "breaks the build. Might be due to firestore package conflicts." Not re-tested
  this pass — the note is someone else's measurement and is respected until
  someone repeats it.
- **`sqlite3_flutter_libs` 0.6.0.** Published as `0.6.0+eol`; the author has
  marked that line end-of-life, so moving onto it is not obviously an
  improvement. Held at 0.5.x (it exists only for `network_tools`' ARP service).

---

## 9. Security invariants

*Enforced: `test/contracts/security_contract_test.dart`.*

This app carries a person's entire message history and a credential to their
Mac. The threat model that matters: a **malicious or compromised server**, a
**network attacker** on the path to a self-hosted server, and **other apps on the
same device**. Each rule below came out of the 2026-07-25 audit.

### 9.1 Server-supplied strings never reach a filesystem path unchecked

*Origin: `Attachment.path` interpolated the server-supplied `transferName` into a
local path. Windows and Linux/macOS stripped separators; the `default:` branch —
**Android and iOS** — applied none, so `../../..` escaped the attachments tree on
the platforms most users are on.*

Everything from the server is attacker-controlled. Route it through
`Attachment.sanitizeFileName` before it touches a path, and keep the
neutralization minimal so legitimate filenames hash to the same path as before
(otherwise every already-downloaded attachment silently orphans).

### 9.2 The auth key never reaches a log

The server password travels as a `?guid=` query parameter — that is the server's
protocol, not a choice this app can make — and the app can **export and share its
logs**. So:

- `ApiInterceptor.onError` strips `guid` and `password` before logging, **from a
  copy**. It previously called `.remove()` on `err.requestOptions.queryParameters`
  directly, which is the live map on the request: logging an error stripped the
  auth key off the request being reported.
- dio's own `LogInterceptor` is **banned** — it prints the full request URI,
  which would write the password into an exportable log.
- Log the request `path`, never the `uri`. (Verified: `DioException.toString()`
  carries only type/message/error, not the URI, so passing an exception to
  `Logger.error` is safe.)

### 9.3 SQL sent to the server stays parameterized

Search and sync send raw SQL fragments to the server as
`{'statement': ..., 'args': ...}`. Every one uses named placeholders (`:term`)
with the value in `args`. Interpolating into the statement is SQL injection
against the server's database.

### 9.4 The Android attack surface stays minimal

- `allowBackup="false"` and `debuggable="false"` stay that way. The auth key is in
  SharedPreferences; `adb backup` would take it off-device.
- **An exported component is an API for every app on the phone.** The socket
  foreground service and its restart receiver were both exported with no
  permission — any installed app could start or stop the socket. Every start site
  uses an explicit same-app `Intent`, which needs no export, so both are now
  `exported="false"`.
- `ExternalIntentReceiver` (Tasker) **must** stay exported to work, so it is
  treated as a hostile-input boundary: an empty stored password can never
  authenticate (it defaults to `""` before setup, so `password=""` would have
  matched), the comparison is constant-time via `MessageDigest.isEqual` (Kotlin
  `==` short-circuits, and any app can invoke this receiver repeatedly and time
  it), and the reply is `setPackage`-targeted at Tasker — an untargeted
  `sendBroadcast` put the server URL on a bus any app could register for, leaking
  it even to callers whose password guess was rejected.

### 9.5 No secrets in the repository

`.env` is git-ignored, and a sweep rejects credential literals in source. A
committed secret is in the git history permanently, even after deletion.

### 9.6 Known accepted risk: blanket certificate trust (UNRESOLVED)

**This is the most significant open security issue in the app and it needs a
product decision, not a patch.**

`HttpOverrides.global` installs `shouldAcceptCertificate`
(`lib/services/network/http_overrides.dart`) as the `badCertificateCallback` for
HTTP *and* WebSocket connections. That callback only runs for a certificate that
has **already failed validation** — untrusted CA, expired, revoked, wrong
hostname — and it returns `true` whenever the connection host equals the
configured server host. There is no pinning, no fingerprint check, and no setting
gating it.

Consequence: an attacker who can intercept traffic to the configured server host
(hostile Wi-Fi, DNS spoofing, ARP poisoning) presents any self-signed
certificate for that hostname and the app accepts it — yielding the full message
stream and the auth key. `cleartextTrafficPermitted="true"` in
`network_security_config.xml` widens this.

The intent is legitimate: BlueBubbles users self-host, often with self-signed
certificates. But note the app **already has a correct mechanism for that** —
`network_security_config.xml` trusts `<certificates src="user" />` and
`UserCertificates` loads user-installed CAs into the `SecurityContext`. A user who
installs their own CA passes *normal* validation. The blanket callback is a
second, much weaker path that makes the first one unnecessary.

Options, in preference order:

1. **Trust-on-first-use pinning.** Record the certificate's SHA-256 fingerprint on
   first successful connection; afterwards require a match and hard-fail on
   change, surfacing a prompt. This is the SSH model: it keeps self-signed working
   and makes interception detectable. Cost: a UI for the change prompt, and a
   recovery path for legitimate certificate rotation.
2. **Gate the bypass behind an explicit, off-by-default setting** with a clear
   warning, and point users at installing their CA instead.
3. **Remove the callback**, relying solely on the user-CA mechanism. Cleanest;
   breaks any existing user who never installed their certificate.

Not done here because every option changes connection behavior in a way that can
lock users out of their own server, and this environment cannot run the app
against a real one. **Until it is resolved, treat the app's transport as
authenticated-by-hostname, not by certificate.**
