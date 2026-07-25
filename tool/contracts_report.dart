/// Prints every current contract violation without failing, for triage.
///
/// The contract tests are the gate; this is the worklist. Run it when you want
/// to see what's left rather than whether the ratchet held:
///
///     dart run tool/contracts_report.dart
library;

import 'dart:io';

import '../test/contracts/ast_sweep.dart';
import '../test/contracts/source_sweep.dart';

void section(String name, List<Violation> violations) {
  stdout.writeln('── $name — ${violations.length}');
  for (final v in violations) {
    stdout.writeln('   ${v.file}:${v.line}');
    stdout.writeln('       ${v.snippet.trim()}');
  }
  stdout.writeln();
}

void main() {
  stdout.writeln('Swept ${productionSources().length} production sources under lib/\n');

  section('ObjectBox query built inside a loop (N+1)', findQueriesInLoops());
  section('Linear scan inside a loop (O(n*m))', findScansInLoops());
  section('.sort() in a build() body', findSortsInBuild());
  section('Public Rx field in @Entity without @Transient', findUnguardedRxEntityFields());
  section('Unclosed query (.build().find/count/...)',
      sweep(RegExp(r'\.build\(\)\s*\.\s*(find|findFirst|findIds|findUnique|count|remove)\s*\(')));
  section('Navigator.of(context) outside NavigationService', sweep(RegExp(r'Navigator\.of\(\s*context\s*\)')));
  section('Raw Scaffold(', sweep(RegExp(r'(?<![A-Za-z_$])Scaffold\(')));
  section('Raw AppBar(', sweep(RegExp(r'(?<![A-Za-z_$])AppBar\(')));
  section('Hardcoded Color(0x...)', sweep(RegExp(r'Color\(0x[0-9a-fA-F]{6,8}\)')));
}
