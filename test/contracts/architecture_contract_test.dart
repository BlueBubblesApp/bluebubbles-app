/// Enforces the layering and theming rules in ENGINEERING-STANDARDS.md §3 and §5.
///
/// Several rules are RATCHETS, not hard zeroes — the codebase doesn't satisfy them
/// repo-wide yet, so the count is pinned to stop it growing. Ceilings only go down.
library;

import 'package:test/test.dart';

import 'source_sweep.dart';

void main() {
  group('api.md — HttpService stays a thin entrypoint', () {
    test('HttpService issues no API requests of its own', () {
      final violations = sweep(
        RegExp(r'\bdio\.(get|post|put|patch|delete|head)\s*[(<]'),
        where: (file) => file.path == 'lib/services/network/http_service.dart',
      );
      // A ratchet of 1, not a file allowlist — allowlisting the file would exempt
      // every future dio call added to it.
      expectAtMostRatchet(
        violations,
        ceiling: httpServiceDioCeiling,
        rule: 'HttpService must not contain API request methods',
        fix: 'Move the method to the matching lib/services/network/api/<domain>_api.dart '
            'and call it via `HttpSvc.<domain>.<method>()`. HttpService owns dio, the '
            'shared request boilerplate, and the sub-service instances — nothing else.',
      );
    });
  });

  group('services.md — navigation goes through NavigationService', () {
    test('Navigator.of(context) is not used in feature code', () {
      final violations = sweep(
        RegExp(r'Navigator\.of\(\s*context\s*\)'),
        allowlist: navigatorAllowlist,
      );
      expectAtMostRatchet(
        violations,
        ceiling: navigatorCeiling,
        rule: 'Feature code must navigate via NavigationSvc, not Navigator.of(context)',
        fix: 'Use NavigationSvc.push / pushAndRemoveUntil / pop. Only '
            'navigator_service.dart itself may touch Navigator directly.',
      );
    });
  });

  group('frontend.md — the shared wrappers are used, not bypassed', () {
    test('screens use BBScaffold, not a raw Scaffold', () {
      final violations = sweep(
        RegExp(r'(?<![A-Za-z_$])Scaffold\('),
        allowlist: scaffoldAllowlist,
      );
      expectAtMostRatchet(
        violations,
        ceiling: scaffoldCeiling,
        rule: 'Screens must use BBScaffold rather than a raw Scaffold',
        fix: 'Swap to BBScaffold (lib/app/wrappers/bb_scaffold.dart). Only that file '
            'may construct a raw Scaffold.',
      );
    });

    test('headers use BBAppBar, not a raw AppBar', () {
      final violations = sweep(
        RegExp(r'(?<![A-Za-z_$])AppBar\('),
        allowlist: appBarAllowlist,
      );
      expectAtMostRatchet(
        violations,
        ceiling: appBarCeiling,
        rule: 'Headers must use BBAppBar rather than a raw AppBar',
        fix: 'Swap to BBAppBar (lib/app/wrappers/bb_app_bar.dart). Only that file may '
            'construct a raw AppBar.',
      );
    });
  });

  group('frontend.md — colors come from the theme', () {
    test('no hardcoded Color(0x...) literals', () {
      final violations = sweep(
        RegExp(r'Color\(0x[0-9a-fA-F]{6,8}\)'),
        allowlist: hardcodedColorAllowlist,
      );
      expectAtMostRatchet(
        violations,
        ceiling: hardcodedColorCeiling,
        rule: 'Colors must derive from context.theme, not hex literals',
        fix: 'Read from context.theme.colorScheme / textTheme, or '
            'ColorSchemeHelpers.bubble(...) for message bubbles. For a genuinely '
            'brand-fixed color, define it once as a named constant and reference that.',
      );
    });

    test('dark-mode branches use ThemeSvc.inDarkMode, not MediaQuery', () {
      final violations = sweep(RegExp(r'MediaQuery\.platformBrightnessOf|MediaQuery\.of\([^)]*\)\.platformBrightness'));
      expect(
        violations,
        isEmpty,
        reason: describeViolations(
          'Dark-mode checks must use ThemeSvc.inDarkMode(context)',
          violations,
          fix: 'MediaQuery reports the OS brightness and ignores the in-app '
              'light/dark/system override, so it disagrees with the rendered theme. '
              'Use ThemeSvc.inDarkMode(context).',
        ),
      );
    });
  });

  group('repo hygiene', () {
    /// Dead code can't be reviewed and reads as live to whoever finds it next.
    test('every barrel export resolves to a file that exists', () {
      final violations = <Violation>[];
      for (final file in productionSources()) {
        final dir = file.path.substring(0, file.path.lastIndexOf('/'));
        final code = stripCommentsAndStrings(file.text);
        // Re-read raw text for the path, since stripping blanks string contents.
        for (final match in RegExp(r'''^\s*export\s+['"]([^'"]+)['"]''', multiLine: true).allMatches(file.text)) {
          final target = match.group(1)!;
          if (target.startsWith('package:') || target.startsWith('dart:')) continue;
          // Only check the export statements that survived comment stripping.
          if (!code.contains('export')) continue;
          final resolved = _normalize('$dir/$target');
          final exists = productionSources().any((f) => f.path == resolved);
          if (!exists) {
            final line = file.lineAt(match.start);
            violations.add(Violation(file.path, line, file.lines[line - 1]));
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason: describeViolations(
          'A barrel exports a file that does not exist',
          violations,
          fix: 'Delete the stale export line. If you removed a file, remove its export '
              'in the same commit.',
        ),
      );
    });
  });
}

/// Collapses `a/b/../c` to `a/c` so relative export targets can be compared.
String _normalize(String path) {
  final parts = <String>[];
  for (final segment in path.split('/')) {
    if (segment == '.' || segment.isEmpty) continue;
    if (segment == '..') {
      if (parts.isNotEmpty) parts.removeLast();
      continue;
    }
    parts.add(segment);
  }
  return parts.join('/');
}

// Ratchets and allowlists — measured 2026-07-25. Ceilings may only go DOWN.

/// The one known call: `downloadFromUrl()`, which fetches an arbitrary URL rather
/// than a server API route, so it has no `<domain>_api.dart` to live in.
const int httpServiceDioCeiling = 1;

const Map<String, String> navigatorAllowlist = {
  'lib/services/ui/navigator/navigator_service.dart':
      'This IS the wrapper every other caller is required to go through.',
};

/// 98 sites across ~45 files — a wide mechanical cleanup nobody has done yet.
const int navigatorCeiling = 98;

const Map<String, String> scaffoldAllowlist = {
  'lib/app/wrappers/bb_scaffold.dart': 'BBScaffold is the wrapper — it must construct the real Scaffold.',
};

const int scaffoldCeiling = 9;

const Map<String, String> appBarAllowlist = {
  'lib/app/wrappers/bb_app_bar.dart': 'BBAppBar is the wrapper — it must construct the real AppBar.',
};

const int appBarCeiling = 2;

const Map<String, String> hardcodedColorAllowlist = {
  'lib/app/components/custom/':
      'Vendored forks of upstream Flutter/Cupertino widgets. The hex values ARE '
          'the upstream constants; changing them would silently diverge these '
          'widgets from the framework behavior they exist to reproduce.',
};

/// 9 sites outside the vendored forks.
const int hardcodedColorCeiling = 9;
