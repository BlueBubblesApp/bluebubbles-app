/// Enforces the ObjectBox rules in ENGINEERING-STANDARDS.md §4.
library;

import 'package:test/test.dart';

import 'ast_sweep.dart';
import 'source_sweep.dart';

void main() {
  group('query lifecycle', () {
    test('every built query is closed — no .build().find() one-liners', () {
      final violations = sweep(
        RegExp(r'\.build\(\)\s*\.\s*(find|findFirst|findIds|findUnique|count|remove)\s*\('),
      );
      expect(
        violations,
        isEmpty,
        reason: describeViolations(
          'A built ObjectBox query must be closed',
          violations,
          fix: 'Assign the query, read it inside `try`, and `close()` it in `finally`:\n'
              '    final q = box.query(...).build();\n'
              '    final List<T> rows;\n'
              '    try { rows = q.find(); } finally { q.close(); }\n'
              'Chaining `.build().find()` makes closing impossible — the handle is '
              'never named, so it leaks for the process lifetime.',
        ),
      );
    });
  });

  group('entity definitions', () {
    /// Private `_`-prefixed backing fields are exempt — objectbox_generator doesn't
    /// persist them, which is why Chat and Message use that shape.
    test('public Rx fields in an @Entity are @Transient', () {
      final violations = findUnguardedRxEntityFields();
      expect(
        violations,
        isEmpty,
        reason: describeViolations(
          'A public Rx field on an @Entity must be marked @Transient()',
          violations,
          fix: 'Either annotate it `@Transient()`, or (preferred) make it a private '
              '`_`-prefixed field behind a plain getter/setter pair — the pattern '
              'Chat.customAvatarPath and Message.error already use. Reactive state '
              'that belongs to the UI should live in lib/app/state/ instead.',
        ),
      );
    });
  });

  group('platform guards', () {
    test('io database models are not imported by the web stubs', () {
      final violations = sweep(
        RegExp(r'''import\s+['"](package:bluebubbles/)?database/io/'''),
        where: (file) => file.isWebStub,
      );
      expect(
        violations,
        isEmpty,
        reason: describeViolations(
          'A web stub must not import an io/ ObjectBox model',
          violations,
          fix: 'The html/ tree exists so web compiles without ObjectBox. Import the '
              'shared DTO from database/global/ instead, or move the shared piece there.',
        ),
      );
    });
  });
}
