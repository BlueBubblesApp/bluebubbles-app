import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:logger/logger.dart';
import 'package:path/path.dart';

/// A [LogOutput] that writes to [latestFileName] and rotates it once the file
/// exceeds [maxFileSizeKB].
///
/// Every isolate that logs — main, GlobalIsolate, IncrementalSyncIsolate, the
/// Android DartWorker — builds its own instance against the same file. On desktop
/// they all forward to one `LogWriter` isolate so the UI isolate does no file I/O;
/// direct writes remain for Android and for the moments before the writer is up,
/// so this still has to tolerate concurrent writers in one process:
///
///  * An event is written with a single [RandomAccessFile.writeFromSync]; writing
///    line by line let another isolate's line land inside a multi-line event
///    (stack traces, breadcrumb dumps). Each write first seeks to the current
///    end: on Windows, Dart's append mode only seeks once at open, so handles
///    overwrote each other. Two isolates writing in the same instant can still
///    collide; true atomic append would need FILE_APPEND_DATA, which Dart doesn't expose.
///  * Rotation is decided from the file's real length and truncates in place.
///    A per-instance byte counter only ever saw its own writes, so every
///    instance rotated on a wrong total; worse, renaming left the other
///    isolates' handles on the rotated-away inode, so their lines silently
///    vanished from the file being collected. Truncating keeps the inode stable
///    for every writer — and since nothing is renamed while handles are open,
///    it also sidesteps the Windows errno 32 (ERROR_SHARING_VIOLATION) that the
///    close-before-rename dance existed to work around.
///
/// All failures are swallowed so the logger never crashes the app.
class RotatingFileOutput extends LogOutput {
  final String dirPath;
  final String latestFileName;
  final int maxFileSizeKB;
  final int maxRotatedFilesCount;
  final Encoding encoding;
  final String Function(DateTime) fileNameFormatter;

  File? _file;
  RandomAccessFile? _raf;

  RotatingFileOutput({
    required this.dirPath,
    required this.latestFileName,
    this.maxFileSizeKB = 1024,
    this.maxRotatedFilesCount = 5,
    this.encoding = utf8,
    required this.fileNameFormatter,
  });

  static const String _writerPortName = 'bb_log_writer';

  SendPort? _writer;

  int get _maxBytes => maxFileSizeKB * 1024;

  @override
  Future<void> init() async {
    // Write directly until the writer is up; the logger doesn't await init().
    _openFile();
    if (!Platform.isWindows && !Platform.isLinux) return;
    final writer = await _ensureWriter();
    if (writer == null) return;
    _writer = writer;
    try {
      _raf?.closeSync();
    } catch (_) {}
    _raf = null;
  }

  Future<SendPort?> _ensureWriter() async {
    final existing = IsolateNameServer.lookupPortByName(_writerPortName);
    if (existing != null) return existing;
    final ready = ReceivePort();
    try {
      await Isolate.spawn(
        _writerMain,
        (ready.sendPort, dirPath, latestFileName, maxFileSizeKB, maxRotatedFilesCount, fileNameFormatter),
        debugName: 'LogWriter',
      );
      await ready.first.timeout(const Duration(seconds: 5));
    } catch (_) {
    } finally {
      ready.close();
    }
    return IsolateNameServer.lookupPortByName(_writerPortName);
  }

  /// The single file writer for every isolate on desktop. Not used on Android: a writer
  /// spawned by the UI engine dies with it while the DartWorker keeps logging.
  static void _writerMain((SendPort, String, String, int, int, String Function(DateTime)) args) {
    final (ready, dirPath, latestFileName, maxFileSizeKB, maxRotatedFilesCount, fileNameFormatter) = args;
    final port = ReceivePort();
    // Lost a spawn race with another isolate; that writer serves everyone.
    if (!IsolateNameServer.registerPortWithName(port.sendPort, _writerPortName)) {
      port.close();
      ready.send(null);
      return;
    }
    final out = RotatingFileOutput(
      dirPath: dirPath,
      latestFileName: latestFileName,
      maxFileSizeKB: maxFileSizeKB,
      maxRotatedFilesCount: maxRotatedFilesCount,
      fileNameFormatter: fileNameFormatter,
    ).._openFile();
    // Everything that arrives before the next event-loop turn goes out in one write.
    final pending = StringBuffer();
    port.listen((message) {
      if (pending.isEmpty) {
        Timer.run(() {
          final chunk = pending.toString();
          pending.clear();
          out._write(chunk);
        });
      }
      pending.write(message as String);
    });
    ready.send(null);
  }

  void _openFile() {
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
    if (event.lines.isEmpty) return;
    // One write per event — never one per line. See the class doc.
    final text = '${event.lines.join('\n')}\n';
    final writer = _writer;
    if (writer != null) {
      writer.send(text);
    } else {
      _write(text);
    }
  }

  void _write(String text) {
    final raf = _raf;
    if (raf == null) return;
    try {
      raf.setPositionSync(raf.lengthSync());
      raf.writeFromSync(encoding.encode(text));
      if (raf.lengthSync() >= _maxBytes) _rotate(raf);
    } catch (_) {}
  }

  void _rotate(RandomAccessFile raf) {
    try {
      // Another isolate may have rotated between our write and this check.
      if (raf.lengthSync() < _maxBytes) return;

      _file!.copySync(join(dirPath, fileNameFormatter(DateTime.now())));
      raf.truncateSync(0);
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
          .where((f) => f.path.endsWith('.log') && !f.path.endsWith(latestFileName))
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
