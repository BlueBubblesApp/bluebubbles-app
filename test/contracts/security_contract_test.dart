/// Enforces ENGINEERING-STANDARDS.md §9 (security invariants).
library;

import 'dart:io';

import 'package:test/test.dart';

import 'source_sweep.dart';

void main() {
  group('§9.1 — server-supplied strings never reach a filesystem path unchecked', () {
    test('Attachment.path routes transferName through sanitizeFileName', () {
      final source = productionSources().firstWhere((f) => f.path == 'lib/database/io/attachment.dart');
      final code = stripCommentsAndStrings(source.text);

      // The getter must not interpolate transferName directly.
      final pathGetter = RegExp(r'String get path \{(.*?)\n  \}', dotAll: true).firstMatch(code);
      expect(pathGetter, isNotNull, reason: 'Could not locate `String get path` in attachment.dart — has it been renamed?');
      final body = pathGetter!.group(1)!;

      expect(
        body.contains('sanitizeFileName'),
        isTrue,
        reason: '\nAttachment.path must pass transferName through sanitizeFileName().\n'
            'transferName comes from the server and is attacker-controlled if the\n'
            'server is malicious or the connection is intercepted. Interpolating it\n'
            'into a path lets it traverse out of the attachment directory.\n',
      );
      expect(
        RegExp(r'\$transferName|\$\{transferName').hasMatch(body),
        isFalse,
        reason: '\nAttachment.path interpolates transferName directly. Use\n'
            'sanitizeFileName("\$transferName") instead — see the path-traversal\n'
            'finding in ENGINEERING-STANDARDS.md §9.1.\n',
      );
    });

    test('sanitizeFileName neutralizes traversal but preserves ordinary names', () {
      // Duplicated, not imported — importing attachment.dart pulls in ObjectBox
      // and dart:ui. The test above proves this is the function actually used.
      String sanitize(String name) {
        final flattened = name.replaceAll('/', '_');
        if (flattened.isEmpty || flattened == '.' || flattened == '..') return 'attachment';
        return flattened;
      }

      // Traversal is neutralized.
      expect(sanitize('../../etc/passwd'), isNot(contains('/')));
      expect(sanitize('..'), 'attachment');
      expect(sanitize('.'), 'attachment');
      expect(sanitize(''), 'attachment');
      expect(sanitize('/absolute/path'), isNot(startsWith('/')));

      // Ordinary filenames are untouched, so paths for already-downloaded
      // attachments still resolve.
      expect(sanitize('IMG_1234.HEIC'), 'IMG_1234.HEIC');
      expect(sanitize('my..file.txt'), 'my..file.txt');
      expect(sanitize('Screen Shot 2026-07-25 at 10.30.00.png'), 'Screen Shot 2026-07-25 at 10.30.00.png');
      expect(sanitize(r'weird\name.png'), r'weird\name.png');
    });
  });

  group('§9.2 — the auth key never reaches a log', () {
    /// The auth key rides in a `?guid=` param and logs are user-exportable.
    test('ApiInterceptor strips guid and password before logging a failed request', () {
      final source = productionSources().firstWhere((f) => f.path == 'lib/services/network/http_service.dart');
      // RAW text, not the stripped form: the thing asserted IS a string literal,
      // and stripping blanks it — the contract could then never match.
      final onError = RegExp(r'void onError\(DioException err.*?\n  \}', dotAll: true).firstMatch(source.text);
      expect(onError, isNotNull, reason: 'Could not locate ApiInterceptor.onError.');
      final body = onError!.group(0)!;

      expect(body.contains('remove("guid")') || body.contains("remove('guid')"), isTrue,
          reason: '\nApiInterceptor.onError must remove "guid" from the params it logs.\n'
              'That key is the server password.\n');
      expect(body.contains('remove("password")') || body.contains("remove('password')"), isTrue,
          reason: '\nApiInterceptor.onError must remove "password" from the params it logs.\n');
    });

    test('request query parameters are copied before redaction, not mutated', () {
      final source = productionSources().firstWhere((f) => f.path == 'lib/services/network/http_service.dart');
      final code = stripCommentsAndStrings(source.text);
      expect(
        RegExp(r'final params = Map<String, dynamic>\.from\(\s*err\.requestOptions\.queryParameters').hasMatch(code),
        isTrue,
        reason: '\nRedaction must operate on a COPY:\n'
            '    final params = Map<String, dynamic>.from(err.requestOptions.queryParameters);\n'
            'Assigning the live map and calling .remove() on it strips the auth key\n'
            'from the actual request as a side effect of logging it.\n',
      );
    });

    /// dio's LogInterceptor prints the full URI, query string and auth key included.
    test('dio LogInterceptor is not installed', () {
      final violations = sweep(RegExp(r'\bLogInterceptor\b'));
      expect(
        violations,
        isEmpty,
        reason: describeViolations(
          "dio's LogInterceptor must not be used",
          violations,
          fix: 'It logs the full request URI, and this app carries the server auth key '
              'in a `?guid=` query parameter — so it would write the password into '
              'logs the user can export and share. Use the redacting ApiInterceptor '
              'in http_service.dart instead.',
        ),
      );
    });
  });

  group('§9.3 — server-supplied SQL stays parameterized', () {
    test('no interpolation into a SQL statement string', () {
      final violations = sweep(RegExp(r"""['"]statement['"]\s*:\s*['"][^'"]*\$"""));
      expect(
        violations,
        isEmpty,
        reason: describeViolations(
          'SQL statements sent to the server must not interpolate values',
          violations,
          fix: "Use a named placeholder and pass the value in 'args':\n"
              "    {'statement': 'message.text LIKE :term', 'args': {'term': ...}}\n"
              'String interpolation here is SQL injection against the server database.',
        ),
      );
    });
  });

  group('§9.4 — Android attack surface stays minimal', () {
    late final String manifest = File('${repoRoot.path}/android/app/src/main/AndroidManifest.xml').readAsStringSync();

    test('the foreground service is not exported', () {
      final block = RegExp(r'<service[^>]*SocketIOForegroundService[^>]*/?>', dotAll: true).firstMatch(manifest);
      expect(block, isNotNull, reason: 'SocketIOForegroundService entry not found in the manifest.');
      expect(
        block!.group(0)!.contains('android:exported="false"'),
        isTrue,
        reason: '\nSocketIOForegroundService must be android:exported="false".\n'
            'It is only ever started via an explicit Intent from inside this app, so\n'
            'exporting it merely lets other apps start or stop the socket service.\n',
      );
    });

    test('the service-restart receiver is not exported', () {
      final block =
          RegExp(r'<receiver[^>]*ForegroundServiceBroadcastReceiver.*?</receiver>', dotAll: true).firstMatch(manifest);
      expect(block, isNotNull, reason: 'ForegroundServiceBroadcastReceiver entry not found.');
      expect(
        block!.group(0)!.contains('android:exported="false"'),
        isTrue,
        reason: '\nForegroundServiceBroadcastReceiver must be android:exported="false".\n'
            'Its only sender is MainActivity.onDestroy() via an explicit Intent.\n',
      );
    });

    test('backup and debuggable stay disabled', () {
      expect(manifest.contains('android:allowBackup="false"'), isTrue,
          reason: '\nandroid:allowBackup must stay "false" — the server auth key lives in\n'
              'SharedPreferences, and adb backup would extract it off-device.\n');
      expect(manifest.contains('android:debuggable="true"'), isFalse,
          reason: '\nandroid:debuggable must never be "true" in the shipped manifest.\n');
    });

    /// This receiver must stay exported to work, so it's a hostile-input boundary.
    test('the Tasker reply broadcast is package-targeted and the password check is constant-time', () {
      final receiver = File('${repoRoot.path}/android/app/src/main/kotlin/com/bluebubbles/messaging/'
              'services/intents/ExternalIntentReceiver.kt')
          .readAsStringSync();

      expect(receiver.contains('setPackage(TASKER_PACKAGE)'), isTrue,
          reason: '\nThe reply must be targeted at Tasker with setPackage(...).\n'
              'An untargeted sendBroadcast discloses the server URL to any app.\n');
      expect(receiver.contains('MessageDigest.isEqual'), isTrue,
          reason: '\nThe password comparison must be constant-time (MessageDigest.isEqual).\n'
              'Kotlin == short-circuits at the first differing byte, and any app can\n'
              'invoke this receiver repeatedly and time it — a prefix oracle.\n');
      expect(receiver.contains('isNullOrEmpty()'), isTrue,
          reason: '\nAn unset stored password must be rejected outright: it defaults to ""\n'
              'before setup, so comparing against it would let password="" match.\n');
    });
  });

  group('§9.5 — no secrets in the repository', () {
    test('.env is git-ignored', () {
      final result = Process.runSync('git', ['check-ignore', '.env'], workingDirectory: repoRoot.path);
      expect(result.exitCode, 0,
          reason: '\n.env must be git-ignored — it carries API keys (KLIPY_API_KEY).\n');
    });

    test('no hardcoded credential literals in source', () {
      final violations = sweep(
        RegExp(
          r'''(?:api[_-]?key|apikey|secret|password|passwd|authToken|bearer)\s*[:=]\s*['"][A-Za-z0-9_\-/+]{16,}['"]''',
          caseSensitive: false,
        ),
      );
      expect(
        violations,
        isEmpty,
        reason: describeViolations(
          'Credentials must not be hardcoded in source',
          violations,
          fix: 'Move it to .env (loaded via flutter_dotenv) or to Settings. A committed '
              'secret is in the git history permanently, even after deletion.',
        ),
      );
    });
  });
}
