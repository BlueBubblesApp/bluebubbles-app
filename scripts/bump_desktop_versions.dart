// Sets the desktop version everywhere it's hardcoded.
//
//   dart run scripts/bump_desktop_versions.dart --beta 2.1.0.0   # flatpak entry marked type="development"
//   dart run scripts/bump_desktop_versions.dart 2.1.0.0          # full release; warns you to write the changelog
//   dart run scripts/bump_desktop_versions.dart --tag 2.1.0+91 2.1.0.0   # desktop-only release tag

import 'dart:io';

/// Repo root, resolved from this script's location so it runs from any cwd.
final root = Platform.script.resolve('../');

/// `--tag` value, if given — the release tag the download URLs should point at instead of pubspec's.
String? tagOverride;

const flatpakMetainfo = 'flatpak/app.bluebubbles.BlueBubbles.metainfo.xml';

File repoFile(String relative) => File.fromUri(root.resolve(relative));

/// Replaces the first line matching [pattern] with [replacement].
///
/// Patterns stop at `[^\r\n]*` rather than `.*` so the line keeps its existing ending — the working
/// tree is CRLF under `core.autocrlf`, even though the repo blobs are LF.
void substitute(String relative, RegExp pattern, String replacement) {
  final file = repoFile(relative);
  final text = file.readAsStringSync();
  if (!pattern.hasMatch(text)) {
    stderr.writeln('error: nothing matched /${pattern.pattern}/ in $relative — did the file change shape?');
    exit(1);
  }
  file.writeAsStringSync(text.replaceAll(pattern, replacement));
  stdout.writeln('$relative: $replacement');
}

RegExp line(String prefix) => RegExp('^$prefix[^\r\n]*', multiLine: true);

void main(List<String> args) {
  final beta = args.contains('--beta');
  final positional = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--beta') {
      continue;
    } else if (args[i] == '--tag') {
      tagOverride = i + 1 < args.length ? args[++i] : '';
    } else if (args[i].startsWith('--tag=')) {
      tagOverride = args[i].substring('--tag='.length);
    } else {
      positional.add(args[i]);
    }
  }
  if (tagOverride?.isEmpty ?? false) {
    stderr.writeln('error: --tag needs a value, eg --tag 2.1.0+91');
    exit(1);
  }
  final version = positional.length == 1 ? positional.single : '';

  if (!RegExp(r'^\d+\.\d+\.\d+\.0$').hasMatch(version)) {
    stderr.writeln('usage: dart run scripts/bump_desktop_versions.dart [--beta] [--tag <tag>] <major.minor.patch.0>');
    stderr.writeln('   eg: dart run scripts/bump_desktop_versions.dart --beta 2.1.0.0');
    stderr.writeln('       (the 4th digit must be 0)');
    stderr.writeln('       --tag overrides the release tag in the download URLs; defaults to pubspec `version:`');
    exit(1);
  }

  substitute('windows/runner/Runner.rc', line('#define VERSION_AS_NUMBER '),
      '#define VERSION_AS_NUMBER ${version.replaceAll('.', ',')}');
  substitute('windows/runner/Runner.rc', line('#define VERSION_AS_STRING '), '#define VERSION_AS_STRING "$version"');
  substitute('windows/bluebubbles_installer_script.iss', line('#define MyAppVersion '),
      '#define MyAppVersion "$version"');
  substitute('pubspec.yaml', line('  msix_version: '), '  msix_version: $version');
  substitute('snap/snapcraft.yaml', line('version: '), 'version: $version');
  // Both arch download URLs point at the release tag, which keys off pubspec's `version:`.
  substitute('snap/snapcraft.yaml', RegExp(r'/releases/download/v[^/]*/'), '/releases/download/v${releaseTag()}/');
  substitute('linux/build.sh', RegExp(r"""jq '\.version = "[^"]*"'"""), """jq '.version = "$version"'""");
  // Screenshots are served from the tag, so they keep matching the release they're shown for.
  substitute(flatpakMetainfo, RegExp(r'/refs/tags/v[^/]*/'), '/refs/tags/v${releaseTag()}/');

  stdout.writeln(addFlatpakRelease(version, beta: beta));
}

/// Flatpak wants a `<release>` entry per version. [beta] gets a bare development entry; a real
/// release gets a changelog skeleton whose `TODO`s you fill in by hand.
String addFlatpakRelease(String version, {required bool beta}) {
  const relative = flatpakMetainfo;
  final file = repoFile(relative);
  final xml = file.readAsStringSync();

  // Re-running (say, to correct the tag) shouldn't duplicate the entry — but its url still has to
  // follow the tag, so refresh that in place.
  final existing = RegExp('<release date="[^"]*" version="${RegExp.escape(version)}"').firstMatch(xml);
  if (existing != null) {
    final end = xml.indexOf('<release ', existing.end);
    final block = xml.substring(existing.end, end == -1 ? xml.length : end);
    final url = RegExp(r'<url type="details">[^<]*</url>').firstMatch(block);
    final fixed = '<url type="details">${releaseTagUrl()}</url>';
    if (url == null || url.group(0) == fixed) {
      return 'note: $relative already has a $version release entry, leaving it alone';
    }
    file.writeAsStringSync(xml.replaceRange(existing.end + url.start, existing.end + url.end, fixed));
    return '$relative: repointed the $version release url at ${releaseTagUrl()}';
  }

  final date = DateTime.now().toIso8601String().split('T').first;
  final lines = beta
      ? ['    <release date="$date" version="$version" type="development" />']
      : [
          '    <release date="$date" version="$version">',
          '      <url type="details">${releaseTagUrl()}</url>',
          '      <description>',
          '        <p>The Big Stuff</p>',
          '        <ul>',
          '          <li>TODO</li>',
          '        </ul>',
          '        <p>The Small Stuff</p>',
          '        <ul>',
          '          <li>TODO</li>',
          '        </ul>',
          '      </description>',
          '    </release>',
        ];

  final newline = xml.contains('\r\n') ? '\r\n' : '\n';
  final entry = lines.join(newline);
  file.writeAsStringSync(xml.replaceFirst('  <releases>', '  <releases>$newline$entry'));

  if (beta) return '$relative: ${lines.single.trim()}';
  return '$relative: ${lines.first.trim()} (+ url and description skeleton)\n\n'
      'WARNING: $version was added as a full release (no --beta).\n'
      '         Replace the TODO items in its <description>, or Flathub will ship a blank changelog.';
}

/// The URL-encoded release tag the download URLs point at, eg `2.1.0%2B90`.
///
/// Defaults to pubspec's `version: X.Y.Z+build` (not the 4-digit desktop version); `--tag` overrides
/// it for desktop-only releases that get their own tag. A leading `v` is stripped either way — the
/// URLs supply it.
String releaseTag() {
  var tag = tagOverride;
  if (tag == null) {
    final pubspec = repoFile('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version: (\S+)', multiLine: true).firstMatch(pubspec);
    if (match == null) {
      stderr.writeln('error: no `version:` line in pubspec.yaml — cannot build the release URL');
      exit(1);
    }
    tag = match.group(1)!;
  }
  return tag.replaceFirst(RegExp('^v'), '').replaceAll('+', '%2B');
}

/// The GitHub release-tag URL for the current pubspec version, eg `.../tag/v2.1.0%2B90`.
String releaseTagUrl() =>
    'https://github.com/BlueBubblesApp/bluebubbles-app/releases/tag/v${releaseTag()}';
