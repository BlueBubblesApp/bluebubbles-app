import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/generated/libmpv/bindings.dart';

// ignore: implementation_imports
import 'package:media_kit/src/player/native/core/native_library.dart';
import 'package:path/path.dart' as p;

/// Debug-only workaround for media_kit's hot-restart crash on desktop.
///
/// On hot restart, media_kit's NativeReferenceHolder sends 'quit' to the mpv handles leaked by
/// the previous isolate, but those handles still have wakeup callbacks pointing at
/// NativeCallables that died with the isolate — the first mpv event then aborts the VM with
/// "Callback invoked after it has been deleted". Clearing the callbacks first (the same call
/// media_kit makes on normal player dispose) makes its cleanup safe.
///
/// Must run before `MediaKit.ensureInitialized()`. Mirrors NativeReferenceHolder's temp-file
/// and buffer layout from media_kit 1.2.x — revisit if media_kit is upgraded past that.
void clearLeakedMpvWakeupCallbacks() {
  if (!kDebugMode || (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)) return;
  try {
    final file = File(p.join(Directory.systemTemp.path, 'com.alexmercerind.media_kit.NativeReferenceHolder.$pid'));
    if (!file.existsSync()) return;
    final address = int.tryParse(file.readAsStringSync().trim());
    if (address == null || address == 0) return;
    NativeLibrary.ensureInitialized();
    final mpv = MPV(DynamicLibrary.open(NativeLibrary.path));
    final buffer = Pointer<IntPtr>.fromAddress(address);
    for (int i = 0; i < 512; i++) {
      final handle = (buffer + i).value;
      if (handle != 0) {
        mpv.mpv_set_wakeup_callback(Pointer.fromAddress(handle).cast(), nullptr, nullptr);
      }
    }
  } catch (e) {
    // Never block startup — worst case the hot restart crashes exactly as it did before.
    debugPrint('Failed to clear leaked mpv wakeup callbacks: $e');
  }
}
