# scripts/ — Developer Scripts

## dart-fix-common-issues.sh
Runs `dart fix --apply` across the project to automatically resolve common lint issues (unused imports, deprecated APIs, etc.).

```bash
bash scripts/dart-fix-common-issues.sh
```

Run this after making broad changes or before committing if the linter is reporting auto-fixable issues.

## bump_desktop_versions.dart
Sets the 4-digit desktop version in every spot it's hardcoded:

| File | What |
|---|---|
| `windows/runner/Runner.rc` | `VERSION_AS_NUMBER` (comma form) + `VERSION_AS_STRING` |
| `windows/bluebubbles_installer_script.iss` | `MyAppVersion` |
| `pubspec.yaml` | `msix_version` |
| `snap/snapcraft.yaml` | `version` + both arch release-download URLs |
| `linux/build.sh` | the `jq '.version = ...'` injection |
| `flatpak/…metainfo.xml` | prepends a `<release>` entry dated today |

Everything but the flatpak entry is a straight substitution; the flatpak entry differs by release type.

```bash
dart run scripts/bump_desktop_versions.dart --beta 2.1.0.0   # flatpak entry gets type="development"
dart run scripts/bump_desktop_versions.dart 2.1.0.0          # full release; warns you to write the changelog
```

Dart rather than shell so there's one implementation for both PowerShell and bash. It runs from any
cwd and preserves each file's existing line endings (the working tree is CRLF under `core.autocrlf`
even though the repo blobs are LF, which trips up `$`-anchored shell regexes).

With `--beta` the flatpak entry is a bare `type="development"` one-liner. Without it, you get a full
release entry pre-filled with a `<url>` (derived from pubspec's `version: X.Y.Z+build`, which is what
the git tag keys off) and a `<description>` skeleton in the usual Big Stuff / Small Stuff shape. The
script warns you to replace its `TODO` items — Flathub ships a blank changelog otherwise.

Idempotent — re-running with the same version won't add a duplicate flatpak release entry. Exits 1
if any expected line stops matching, so a renamed field fails loudly instead of silently skipping.

`pubspec.yaml`'s `version:` (Flutter version+build) is bumped separately, by hand. The snapcraft
download URLs and the flatpak `<url>` key off *that* value, not the 4-digit desktop version, so bump
pubspec first and this script will pick it up.
