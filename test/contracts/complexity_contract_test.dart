/// Enforces ENGINEERING-STANDARDS.md §1 (complexity) and §2 (algorithms).
library;

import 'package:test/test.dart';

import 'ast_sweep.dart';
import 'source_sweep.dart';

void main() {
  group('§2.1 — lookups are hash lookups, never scans', () {
    test('no list-membership scan: .toList().contains(...)', () {
      final violations = sweep(RegExp(r'\.toList\(\)\s*\.contains\('));
      expect(
        violations,
        isEmpty,
        reason: describeViolations(
          'Membership tests must not build a List and scan it',
          violations,
          fix: 'Expose the collection as a `Set` (ideally `static const`) and call '
              '`.contains()` on that — O(1) instead of O(n) plus an allocation. '
              'See ReactionTypes.all in lib/helpers/ui/reaction_helpers.dart.',
        ),
      );
    });

    /// Pinned separately so it can't come back even if the generic rule relaxes.
    test('ReactionTypes membership uses the Set, not toList()', () {
      final violations = sweep(RegExp(r'ReactionTypes\.toList\(\)\s*\.contains\('));
      expect(
        violations,
        isEmpty,
        reason: describeViolations(
          'ReactionTypes membership must use ReactionTypes.all',
          violations,
          fix: 'Use `ReactionTypes.all.contains(x)`. `toList()` exists only for '
              'ordered UI rendering (the reaction picker).',
        ),
      );
    });
  });

  group('§2.2 — no linear scan inside a loop over another collection', () {
    /// AST-parsed, not grepped: a text window can't tell a loop body from a
    /// callback written inside one.
    test('no firstWhere/indexWhere/indexOf inside a loop body', () {
      final violations = findScansInLoops(allowlist: scanInLoopAllowlist);
      expectAtMostRatchet(
        violations,
        ceiling: scanInLoopCeiling,
        rule: 'A loop body must not linear-scan another collection (O(n*m))',
        fix: 'Build a Map/Set index of the inner collection ONCE before the loop, '
            'then look up by key inside it. See the `byGuid` index in '
            'MessagesService.loadChunk or `dbChatsByGuid` in search_query_helper.dart.',
      );
    });
  });

  group('§2.3 — N+1 database queries', () {
    test('no ObjectBox query constructed inside a loop body', () {
      final violations = findQueriesInLoops(allowlist: queryInLoopAllowlist);
      expectAtMostRatchet(
        violations,
        ceiling: queryInLoopCeiling,
        rule: 'A loop body must not construct a database query (N+1)',
        fix: 'Batch the whole loop into ONE query with a set condition '
            '(`Property.oneOf([...])`), then index the result by key. '
            'If the query genuinely cannot be batched (e.g. per-chat "newest 1 '
            'by date", which ObjectBox cannot express as one query), add the file '
            'to queryInLoopAllowlist with that reason.',
      );
    });
  });

  group('§1.2 — per-build work is O(1) in the number of items', () {
    test('no .sort() in a widget build() body', () {
      final violations = findSortsInBuild(allowlist: sortInBuildAllowlist);
      expectAtMostRatchet(
        violations,
        ceiling: sortInBuildCeiling,
        rule: 'build() must not sort — sorting is O(n log n) per frame',
        fix: 'Sort once where the data changes (a service, a controller, or a '
            'cached field), not once per rebuild. If you only need the min/max, '
            'use a single linear pass instead of a sort — see MessagesService._newest.',
      );
    });
  });
}

// Ratchets and allowlists. Ceilings are measured counts and may only be lowered.

/// One query per *page* is pagination, not an N+1 over rows.
const Map<String, String> queryInLoopAllowlist = {
  'lib/services/backend/sync/full_sync_manager.dart': 'Paginated sync.',
  'lib/services/backend/sync/chat_sync_manager.dart': 'Paginated sync.',
  'lib/services/backend/sync/incremental_sync_manager.dart': 'Paginated sync.',
};

/// Measured 2026-07-25. Worklist for the 13:
///
/// Inherent (ObjectBox has no "newest 1 row per group"):
///   chat_actions:465, sync_actions:394, chat_latest_message_migration:43
/// One-shot migration, pre-launch, not user-facing:
///   database:237, database:250, chat_latest_message_migration:30,
///   message_handle_relationship_migration:48
/// Cold-path fallback behind a hash fast-path:
///   sync_actions:299
/// FIXABLE — batch with oneOf(...) and lower this ceiling:
///   chat_actions:374, chat_actions:475, chat_actions:561,
///   contact_v2_actions:299,
///   contact_v2_actions:408 (uses `contains`, which has no set form — needs a rethink)
const int queryInLoopCeiling = 13;

/// Measured 2026-07-25, down from 8. The 5 left are bounded by an n that can't grow
/// with the database (one chat's participants, one message's parts, the user's
/// selection), so they're O(small) not O(rows):
///   chat_creator_controller:254, message_state:699, message_state:715,
///   chat_actions:767, messages_service:215
const int scanInLoopCeiling = 5;

const Map<String, String> scanInLoopAllowlist = {};

/// Both in `preset_theme_strip.dart`, which derives theme collections per build.
/// Off the messaging hot path; fix is to derive them once in the controller.
const int sortInBuildCeiling = 2;

const Map<String, String> sortInBuildAllowlist = {};
