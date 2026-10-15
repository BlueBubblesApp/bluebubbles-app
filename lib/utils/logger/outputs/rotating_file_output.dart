import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart';

/// A [LogOutput] that writes to `<filePrefix>-latest.log` and rotates it to
/// `<filePrefix>-<date>-<epoch>.log` once it exceeds [maxFileSizeKB].
///
/// Every isolate that logs — main, GlobalIsolate, IncrementalSyncIsolate, the
/// Android DartWorker — gets its own [filePrefix], so each file has a single
/// writer. Sharing one file let isolates overwrite and interleave each other's
/// lines, and rotating it from one isolate pulled it out from under the others.
///
///  * An event is written with a single synchronous write, so it reaches the OS
///    before the log call returns and survives the process crashing right after.
///  * Dart never opens files with O_APPEND: [FileMode.append] seeks to the end once
///    at open, and the single writer's position stays at the end from there on.
///  * Rotation copies the file, truncates it in place and rewinds the handle to
///    match, so the handle stays valid.
///
/// All failures are swallowed so the logger never crashes the app.
class RotatingFileOutput extends LogOutput {
  final String dirPath;
  final String filePrefix;
  final int maxFileSizeKB;
  final int maxRotatedFilesCount;
  final Encoding encoding;

  File? _file;
  RandomAccessFile? _raf;

  RotatingFileOutput({
    required this.dirPath,
    required this.filePrefix,
    this.maxFileSizeKB = 1024,
    this.maxRotatedFilesCount = 5,
    this.encoding = utf8,
  });

  String get latestFileName => '$filePrefix-latest.log';

  /// Matches this prefix's rotated files only. The date makes `bluebubbles-2026-…` distinct from
  /// another isolate's `bluebubbles-globalisolate-…`.
  RegExp get _rotatedFilePattern => RegExp('^${RegExp.escape(filePrefix)}-\\d{4}-\\d{2}-\\d{2}-\\d+\\.log\$');

  int get _maxBytes => maxFileSizeKB * 1024;

  @override
  Future<void> init() async {
    try {
      _file = File(join(dirPath, latestFileName));
      if (!_file!.existsSync()) {
        _file!.createSync(recursive: true);
      }
      _raf = _file!.openSync(mode: FileMode.append);
    } catch (_) {
      _raf = null;
    }
  }

  @override
  void output(OutputEvent event) {
    final raf = _raf;
    if (raf == null || event.lines.isEmpty) return;
    try {
      // One write per event, never one per line, so multi-line events stay together.
      raf.writeFromSync(encoding.encode('${event.lines.join('\n')}\n'));
      if (raf.positionSync() >= _maxBytes) _rotate(raf);
    } catch (_) {}
  }

  void _rotate(RandomAccessFile raf) {
    try {
      final now = DateTime.now();
      final date = now.toIso8601String().split('T').first;
      _file!.copySync(join(dirPath, '$filePrefix-$date-${now.millisecondsSinceEpoch ~/ 1000}.log'));
      raf.truncateSync(0);
      // Without O_APPEND the next write would land at the old offset, leaving a gap of zeros.
      raf.setPositionSync(0);
      _pruneOldFiles();
    } catch (_) {
      // Rotation must never crash the logger. The file stays oversized and we
      // retry on the next event, which is strictly better than losing lines.
    }
  }

  void _pruneOldFiles() {
    try {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) return;

      final rotated = dir
          .listSync()
          .whereType<File>()
          .where((f) => _rotatedFilePattern.hasMatch(basename(f.path)))
          .toList()
        ..sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));

      while (rotated.length > maxRotatedFilesCount) {
        try {
          rotated.removeAt(0).deleteSync();
        } catch (_) {}
      }
    } catch (_) {}
  }

  @override
  Future<void> destroy() async {
    try {
      _raf?.closeSync();
    } catch (_) {}
    _raf = null;
  }
}
