import 'dart:ffi';
import 'dart:io';

import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

/// The system emoji font fontconfig picks, or null if there isn't one. Listed in the theme's font fallback on Linux.
final ({String path, String family})? linuxEmojiFont = Platform.isLinux ? _findEmojiFont() : null;

typedef _NameParse = Pointer<Void> Function(Pointer<Utf8>);
typedef _Substitute = Int32 Function(Pointer<Void>, Pointer<Void>, Int32);
typedef _SubstituteDart = int Function(Pointer<Void>, Pointer<Void>, int);
typedef _DefaultSubstitute = Void Function(Pointer<Void>);
typedef _DefaultSubstituteDart = void Function(Pointer<Void>);
typedef _FontMatch = Pointer<Void> Function(Pointer<Void>, Pointer<Void>, Pointer<Int32>);
typedef _GetString = Int32 Function(Pointer<Void>, Pointer<Utf8>, Int32, Pointer<Pointer<Utf8>>);
typedef _GetStringDart = int Function(Pointer<Void>, Pointer<Utf8>, int, Pointer<Pointer<Utf8>>);
typedef _GetCharSet = Int32 Function(Pointer<Void>, Pointer<Utf8>, Int32, Pointer<Pointer<Void>>);
typedef _GetCharSetDart = int Function(Pointer<Void>, Pointer<Utf8>, int, Pointer<Pointer<Void>>);
typedef _HasChar = Int32 Function(Pointer<Void>, Uint32);
typedef _HasCharDart = int Function(Pointer<Void>, int);

/// Flutter's Linux embedder never asks fontconfig for per-character fallback, so emoji render as tofu (#3492).
/// Ask fontconfig for the system emoji font ourselves and register it with the engine.
Future<void> loadLinuxEmojiFont() async {
  final font = linuxEmojiFont;
  if (font == null) return;
  try {
    final bytes = await File(font.path).readAsBytes();
    await (FontLoader(font.family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    Logger.info('Loaded system emoji font ${font.family} (${font.path})', tag: 'LinuxEmojiFont');
  } catch (e, s) {
    Logger.warn('Failed to load system emoji font ${font.path}', error: e, trace: s, tag: 'LinuxEmojiFont');
  }
}

({String path, String family})? _findEmojiFont() {
  try {
    final fc = DynamicLibrary.open('libfontconfig.so.1');
    final nameParse = fc.lookupFunction<_NameParse, _NameParse>('FcNameParse');
    final configSubstitute = fc.lookupFunction<_Substitute, _SubstituteDart>('FcConfigSubstitute');
    final defaultSubstitute = fc.lookupFunction<_DefaultSubstitute, _DefaultSubstituteDart>('FcDefaultSubstitute');
    final fontMatch = fc.lookupFunction<_FontMatch, _FontMatch>('FcFontMatch');
    final getString = fc.lookupFunction<_GetString, _GetStringDart>('FcPatternGetString');
    final getCharSet = fc.lookupFunction<_GetCharSet, _GetCharSetDart>('FcPatternGetCharSet');
    final hasChar = fc.lookupFunction<_HasChar, _HasCharDart>('FcCharSetHasChar');
    final destroy = fc.lookupFunction<_DefaultSubstitute, _DefaultSubstituteDart>('FcPatternDestroy');

    return using((arena) {
      final pattern = nameParse('emoji'.toNativeUtf8(allocator: arena));
      if (pattern == nullptr) return null;
      configSubstitute(nullptr, pattern, 0); // FcMatchPattern
      defaultSubstitute(pattern);
      final match = fontMatch(nullptr, pattern, arena<Int32>());
      destroy(pattern);
      if (match == nullptr) return null;
      try {
        // fontconfig always returns its best match, so make sure it actually has emoji (U+1F600).
        final charset = arena<Pointer<Void>>();
        if (getCharSet(match, 'charset'.toNativeUtf8(allocator: arena), 0, charset) != 0 ||
            hasChar(charset.value, 0x1F600) == 0) {
          return null;
        }
        final file = arena<Pointer<Utf8>>();
        final family = arena<Pointer<Utf8>>();
        if (getString(match, 'file'.toNativeUtf8(allocator: arena), 0, file) != 0 ||
            getString(match, 'family'.toNativeUtf8(allocator: arena), 0, family) != 0) {
          return null;
        }
        return (path: file.value.toDartString(), family: family.value.toDartString());
      } finally {
        destroy(match);
      }
    });
  } catch (e, s) {
    Logger.warn('fontconfig emoji lookup failed', error: e, trace: s, tag: 'LinuxEmojiFont');
    return null;
  }
}
