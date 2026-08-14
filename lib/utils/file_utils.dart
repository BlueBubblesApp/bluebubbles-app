import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:bluebubbles/utils/gif_utils.dart';
import 'package:file_picker/file_picker.dart' hide PlatformFile;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:universal_io/io.dart';

/// Opens [path]'s containing folder in the desktop file manager, highlighting the file where the
/// platform allows. Under flatpak, xdg-open/OpenURI can't reach a host path without a filesystem
/// grant, so it uses FileManager1 (granted via --talk-name in the manifest), which opens the path
/// host-side by URI string — no grant needed.
Future<void> revealInFileManager(String path) async {
  if (Platform.isWindows) {
    await Process.start('explorer', [dirname(path)]);
  } else if (Platform.isMacOS) {
    await Process.start('open', ['-R', path]);
  } else if (Platform.environment.containsKey('FLATPAK_ID')) {
    await Process.run('gdbus', [
      'call', '--session',
      '--dest', 'org.freedesktop.FileManager1',
      '--object-path', '/org/freedesktop/FileManager1',
      '--method', 'org.freedesktop.FileManager1.ShowItems',
      "['${Uri.file(path)}']", '',
    ]);
  } else {
    await Process.start('xdg-open', [dirname(path)]);
  }
}

/// Moves [source] onto [targetPath], by rename where the filesystem allows it.
Future<void> moveFile(File source, String targetPath) async {
  try {
    await source.rename(targetPath);
    return;
  } on PathNotFoundException {
    rethrow;
  } on FileSystemException {
    // Cross-device, or the destination can't be replaced.
  }
  await source.copy(targetPath);
  try {
    await source.delete();
  } on FileSystemException {
    // Whatever
  }
}

/// Desktop "Save As": asks where to put the file, then puts it there. Returns
/// the path it was saved to, or null if the user cancelled the dialog.
Future<String?> saveFileAs({
  required String fileName,
  String? initialDirectory,
  String? sourcePath,
  Uint8List? bytes,
  List<String>? allowedExtensions,
}) async {
  assert(sourcePath != null || bytes != null, 'saveFileAs needs either a sourcePath or bytes');
  final String? savePath = await FilePicker.saveFile(
    initialDirectory: initialDirectory,
    dialogTitle: 'Choose a location to save this file',
    fileName: fileName,
    lockParentWindow: true,
    type: allowedExtensions != null ? FileType.custom : FileType.any,
    allowedExtensions: allowedExtensions,
  );
  // Cancelled. Overwrite confirmation is the native dialog's job, so anything
  // that comes back here is a location the user has agreed to write to.
  if (savePath == null) return null;

  if (sourcePath != null) {
    await File(sourcePath).copy(savePath);
  } else {
    await File(savePath).writeAsBytes(bytes!);
  }
  return savePath;
}

Future<PlatformFile?> loadPathAsFile(String path) async {
  final file = File(path);
  if (!(await file.exists())) return null;

  final bytes = await file.readAsBytes();
  return PlatformFile(
    name: basename(file.path),
    bytes: bytes,
    size: bytes.length,
    path: path,
  );
}

/// Changes the delay time of any GIF with 0 delay time.
/// https://giflib.sourceforge.net/whatsinagif/animation_and_transparency.html
///
/// Runs on the calling isolate: [rewriteZeroDelayGifFrames] only reads block
/// headers and skips the compressed payloads by arithmetic, so it touches a few
/// hundred bytes regardless of file size. Handing it to [compute] would cost a
/// full copy of the image across the port — by far the expensive part — to save
/// work that is already negligible.
Future<Uint8List> fixSpeedyGifs(Uint8List image) async {
  return rewriteZeroDelayGifFrames(image);
}
