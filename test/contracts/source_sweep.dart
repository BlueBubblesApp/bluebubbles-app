/// Shared machinery for the contract tests. Contracts sweep every production
/// source rather than pinning known hot spots, so they catch files that don't
/// exist yet. See ENGINEERING-STANDARDS.md §6.
library;

import 'dart:io';

/// Repo root, so tests work from any working directory.
final Directory repoRoot = _findRepoRoot();

Directory _findRepoRoot() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not locate repo root (no pubspec.yaml found walking up).');
    }
    dir = parent;
  }
}

/// A production Dart source file under `lib/`, with its text and repo-relative path.
class SourceFile {
  SourceFile(this.path, this.text);

  /// Repo-relative, always forward-slashed (identical on Windows runners).
  final String path;
  final String text;

  late final List<String> lines = text.split('\n');

  /// 1-indexed line number for a character offset — for actionable failures.
  int lineAt(int offset) => text.substring(0, offset).split('\n').length;

  String get basename => path.split('/').last;

  bool get isWebStub => path.startsWith('lib/database/html/');
  bool get isGenerated => path.startsWith('lib/generated/');
}

/// Directories excluded from every sweep.
const Map<String, String> _excludedPrefixes = {
  // Machine-written by build_runner; editing it is already forbidden.
  'lib/generated/': 'generated code — never hand-edited',
};

List<SourceFile>? _cache;

/// Every hand-written production source under `lib/`.
List<SourceFile> productionSources() {
  if (_cache != null) return _cache!;
  final libDir = Directory('${repoRoot.path}/lib');
  final rootPath = repoRoot.path;
  final files = <SourceFile>[];

  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final relative = entity.path.substring(rootPath.length + 1).replaceAll(r'\', '/');
    if (_excludedPrefixes.keys.any(relative.startsWith)) continue;
    files.add(SourceFile(relative, entity.readAsStringSync()));
  }

  files.sort((a, b) => a.path.compareTo(b.path));
  return _cache = files;
}

/// Strips comments and string literals so a rule can't be tripped by its own
/// explanatory comment or by a substring inside a string. Removed spans become
/// equal-length spaces, so reported line numbers stay accurate.
///
/// Don't use this when the thing you're asserting IS a string literal.
String stripCommentsAndStrings(String source) {
  final out = StringBuffer();
  var i = 0;
  final n = source.length;

  void blank(int count) => out.write(' ' * count);

  while (i < n) {
    final c = source[i];
    final next = i + 1 < n ? source[i + 1] : '';

    if (c == '/' && next == '/') {
      final end = source.indexOf('\n', i);
      final stop = end == -1 ? n : end;
      blank(stop - i);
      i = stop;
      continue;
    }
    if (c == '/' && next == '*') {
      final end = source.indexOf('*/', i + 2);
      final stop = end == -1 ? n : end + 2;
      for (var k = i; k < stop; k++) {
        out.write(source[k] == '\n' ? '\n' : ' ');
      }
      i = stop;
      continue;
    }
    if (c == "'" || c == '"') {
      // Raw and triple-quoted forms included.
      final isTriple = i + 2 < n && source[i + 1] == c && source[i + 2] == c;
      final delimiter = isTriple ? c * 3 : c;
      var j = i + delimiter.length;
      while (j < n) {
        if (source[j] == r'\') {
          j += 2;
          continue;
        }
        if (source.startsWith(delimiter, j)) {
          j += delimiter.length;
          break;
        }
        j++;
      }
      final stop = j > n ? n : j;
      for (var k = i; k < stop; k++) {
        out.write(source[k] == '\n' ? '\n' : ' ');
      }
      i = stop;
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// Whether [path] is exempted by [allowlist]. A key ending in `/` exempts a
/// directory subtree; anything else must match exactly, so an exemption can't
/// silently widen to a sibling file.
bool isAllowlisted(String path, Map<String, String> allowlist) {
  for (final entry in allowlist.keys) {
    if (entry.endsWith('/') ? path.startsWith(entry) : path == entry) return true;
  }
  return false;
}

/// A single contract violation, rendered as a clickable `path:line` plus context.
class Violation {
  Violation(this.file, this.line, this.snippet);

  final String file;
  final int line;
  final String snippet;

  @override
  String toString() => '  $file:$line\n      ${snippet.trim()}';
}

/// Formats violations into a message that says what to do, not just what's wrong.
String describeViolations(String rule, List<Violation> violations, {required String fix}) {
  final buffer = StringBuffer()
    ..writeln()
    ..writeln('Contract violated: $rule')
    ..writeln('${violations.length} violation(s):')
    ..writeln();
  for (final v in violations.take(25)) {
    buffer.writeln(v);
  }
  if (violations.length > 25) {
    buffer.writeln('  ... and ${violations.length - 25} more');
  }
  buffer
    ..writeln()
    ..writeln('How to fix: $fix')
    ..writeln()
    ..writeln('If a call site is a genuine, justified exception, add it to this '
        'contract\'s allowlist WITH a written reason — never delete or weaken '
        'the rule (ENGINEERING-STANDARDS.md §6).');
  return buffer.toString();
}

/// Asserts a violation count never grows past a recorded ceiling — for rules the
/// codebase doesn't satisfy repo-wide yet, where locking at zero would mean a huge
/// unreviewed refactor or deleting the rule.
///
/// **The ceiling may only move down.** Fails when the count drops below it too, so
/// a stale floor can't quietly stop meaning anything.
void expectAtMostRatchet(
  List<Violation> violations, {
  required int ceiling,
  required String rule,
  required String fix,
}) {
  if (violations.length > ceiling) {
    throw StateError(
      '${describeViolations(rule, violations, fix: fix)}\n'
      'This rule is a RATCHET currently pinned at $ceiling known violation(s); '
      'this tree has ${violations.length}. You added ${violations.length - ceiling}. '
      'Fix them — do not raise the ceiling.',
    );
  }
  if (violations.length < ceiling) {
    throw StateError(
      '\nRatchet needs tightening: "$rule"\n'
      'Recorded ceiling is $ceiling but this tree only has ${violations.length} '
      'violation(s) — you fixed ${ceiling - violations.length}.\n'
      'Lower the ceiling to ${violations.length} in this same commit so the '
      'progress is locked in and cannot regress.',
    );
  }
}

/// Finds every match of [pattern] in each production source, skipping comments
/// and string literals, and skipping any file whose path is in [allowlist].
List<Violation> sweep(
  RegExp pattern, {
  Map<String, String> allowlist = const {},
  bool Function(SourceFile file)? where,
}) {
  final violations = <Violation>[];
  for (final file in productionSources()) {
    if (isAllowlisted(file.path, allowlist)) continue;
    if (where != null && !where(file)) continue;
    final code = stripCommentsAndStrings(file.text);
    for (final match in pattern.allMatches(code)) {
      final line = file.lineAt(match.start);
      violations.add(Violation(file.path, line, file.lines[line - 1]));
    }
  }
  return violations;
}
