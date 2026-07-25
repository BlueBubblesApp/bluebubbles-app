/// AST sweeps for the structural contracts. Text patterns can't express "inside a
/// loop body" — a regex window flags callbacks written in one, which is correct
/// code, and a contract that cries wolf gets ignored.
library;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'source_sweep.dart';

/// Parses [file] into a compilation unit. Parse only, no resolution — needs no
/// package config and runs over all ~570 sources in one test. Any diagnostic here
/// is a syntax error, meaning a verdict on the file would be meaningless.
CompilationUnit parseSource(SourceFile file) {
  final result = parseString(content: file.text, throwIfDiagnostics: false);
  if (result.errors.isNotEmpty) {
    throw StateError('Failed to parse ${file.path}: ${result.errors.first}');
  }
  return result.unit;
}

/// Maps a character offset to a 1-indexed line number.
int lineOf(SourceFile file, int offset) => file.lineAt(offset);

/// Tracks whether the current node is in a loop body, and separately whether it's
/// inside a closure nested in that loop. The distinction is the whole point:
/// ```dart
/// for (final id in ids) { box.query(...).build(); }              // violation
/// for (final c in cs) { add(Button(onTap: () => box.query(...))) } // fine
/// ```
abstract class LoopAwareVisitor extends RecursiveAstVisitor<void> {
  int _loopDepth = 0;
  int _functionDepthAtLoopEntry = -1;
  int _functionDepth = 0;

  /// True when the current node is directly in a loop body — not inside a
  /// closure that merely happens to be written within one.
  bool get inLoopBody => _loopDepth > 0 && _functionDepth == _functionDepthAtLoopEntry;

  void _enterLoop(void Function() visitChildren) {
    final previousEntry = _functionDepthAtLoopEntry;
    _loopDepth++;
    if (_loopDepth == 1 || _functionDepth != _functionDepthAtLoopEntry) {
      _functionDepthAtLoopEntry = _functionDepth;
    }
    visitChildren();
    _loopDepth--;
    _functionDepthAtLoopEntry = previousEntry;
  }

  @override
  void visitForStatement(ForStatement node) => _enterLoop(() => super.visitForStatement(node));

  @override
  void visitForElement(ForElement node) => _enterLoop(() => super.visitForElement(node));

  @override
  void visitWhileStatement(WhileStatement node) => _enterLoop(() => super.visitWhileStatement(node));

  @override
  void visitDoStatement(DoStatement node) => _enterLoop(() => super.visitDoStatement(node));

  @override
  void visitFunctionExpression(FunctionExpression node) {
    _functionDepth++;
    super.visitFunctionExpression(node);
    _functionDepth--;
  }
}

/// Returns the dotted method-call chain target text for a method invocation,
/// e.g. `Database.messages.query` for `Database.messages.query(...)`.
String calleeSource(MethodInvocation node) {
  final target = node.target;
  return target == null ? node.methodName.name : '${target.toSource()}.${node.methodName.name}';
}

/// Whether [node] is an ObjectBox query construction (`<box>.query(...)`).
bool isQueryConstruction(MethodInvocation node) => node.methodName.name == 'query';

/// Linear-scan methods. One of these inside a loop over another collection is the
/// O(n*m) shape.
const Set<String> linearScanMethods = {
  'firstWhere',
  'firstWhereOrNull',
  'lastWhere',
  'lastWhereOrNull',
  'singleWhere',
  'singleWhereOrNull',
  'indexWhere',
  'lastIndexWhere',
  'indexOf',
};

/// Finds loop bodies that construct an ObjectBox query — the N+1 shape.
List<Violation> findQueriesInLoops({Map<String, String> allowlist = const {}}) {
  final out = <Violation>[];
  for (final file in productionSources()) {
    if (isAllowlisted(file.path, allowlist)) continue;
    final visitor = _QueryInLoopVisitor(file);
    parseSource(file).accept(visitor);
    out.addAll(visitor.violations);
  }
  return out;
}

class _QueryInLoopVisitor extends LoopAwareVisitor {
  _QueryInLoopVisitor(this.file);

  final SourceFile file;
  final List<Violation> violations = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (inLoopBody && isQueryConstruction(node)) {
      final line = lineOf(file, node.offset);
      violations.add(Violation(file.path, line, file.lines[line - 1]));
    }
    super.visitMethodInvocation(node);
  }
}

/// Finds loop bodies that run a linear scan over a collection — O(n*m).
List<Violation> findScansInLoops({Map<String, String> allowlist = const {}}) {
  final out = <Violation>[];
  for (final file in productionSources()) {
    if (isAllowlisted(file.path, allowlist)) continue;
    final visitor = _ScanInLoopVisitor(file);
    parseSource(file).accept(visitor);
    out.addAll(visitor.violations);
  }
  return out;
}

class _ScanInLoopVisitor extends LoopAwareVisitor {
  _ScanInLoopVisitor(this.file);

  final SourceFile file;
  final List<Violation> violations = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (inLoopBody && linearScanMethods.contains(node.methodName.name) && node.target != null) {
      final line = lineOf(file, node.offset);
      violations.add(Violation(file.path, line, file.lines[line - 1]));
    }
    super.visitMethodInvocation(node);
  }
}

/// Finds `.sort(...)` in a `build()` body, excluding callbacks declared inside it
/// (those run per user action, not per frame).
List<Violation> findSortsInBuild({Map<String, String> allowlist = const {}}) {
  final out = <Violation>[];
  for (final file in productionSources()) {
    if (isAllowlisted(file.path, allowlist)) continue;
    final visitor = _SortInBuildVisitor(file);
    parseSource(file).accept(visitor);
    out.addAll(visitor.violations);
  }
  return out;
}

class _SortInBuildVisitor extends RecursiveAstVisitor<void> {
  _SortInBuildVisitor(this.file);

  final SourceFile file;
  final List<Violation> violations = [];
  bool _inBuild = false;
  int _functionDepth = 0;
  int _buildFunctionDepth = -1;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final isBuild = node.name.lexeme == 'build' || node.name.lexeme == 'builder';
    if (!isBuild) {
      super.visitMethodDeclaration(node);
      return;
    }
    _inBuild = true;
    _buildFunctionDepth = _functionDepth;
    super.visitMethodDeclaration(node);
    _inBuild = false;
    _buildFunctionDepth = -1;
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    _functionDepth++;
    super.visitFunctionExpression(node);
    _functionDepth--;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Only build's own statements. An Obx(() => ...) builder is also per-frame, but
    // telling it from onPressed needs resolution — so flag the direct body only
    // rather than emit false positives.
    if (_inBuild && _functionDepth == _buildFunctionDepth && node.methodName.name == 'sort') {
      final line = lineOf(file, node.offset);
      violations.add(Violation(file.path, line, file.lines[line - 1]));
    }
    super.visitMethodInvocation(node);
  }
}

/// Finds public `Rx*` fields in an `@Entity()` that aren't `@Transient()`.
/// Private `_`-prefixed fields are excluded — objectbox_generator doesn't persist
/// them, so the backing-field pattern in `Chat`/`Message` is already safe.
List<Violation> findUnguardedRxEntityFields({Map<String, String> allowlist = const {}}) {
  final out = <Violation>[];
  for (final file in productionSources()) {
    if (isAllowlisted(file.path, allowlist)) continue;
    if (!file.path.startsWith('lib/database/')) continue;
    final unit = parseSource(file);
    for (final declaration in unit.declarations) {
      if (declaration is! ClassDeclaration) continue;
      final isEntity = declaration.metadata.any((m) => m.name.name == 'Entity');
      if (!isEntity) continue;
      for (final member in declaration.members) {
        if (member is! FieldDeclaration) continue;
        final typeName = member.fields.type?.toSource() ?? '';
        if (!RegExp(r'^Rx[A-Za-z]*\b|^Rxn?\<').hasMatch(typeName)) continue;
        final allPrivate = member.fields.variables.every((v) => v.name.lexeme.startsWith('_'));
        if (allPrivate) continue;
        final hasTransient = member.metadata.any((m) => m.name.name == 'Transient');
        if (hasTransient) continue;
        final line = lineOf(file, member.offset);
        out.add(Violation(file.path, line, file.lines[line - 1]));
      }
    }
  }
  return out;
}
