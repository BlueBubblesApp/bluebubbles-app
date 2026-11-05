import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:bluebubbles/env.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/outputs/log_stream_output.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:universal_io/io.dart';
import 'package:get_it/get_it.dart';

// ignore: library_prefixes
import 'package:logger/logger.dart' as LoggerFactory;

import 'outputs/debug_console_output.dart';
import 'outputs/file_output_wrapper.dart';
import 'outputs/rotating_file_output.dart';

// ignore: non_constant_identifier_names
BaseLogger get Logger => GetIt.I<BaseLogger>();

enum LogLevel { INFO, WARN, ERROR, DEBUG, TRACE, FATAL }

const Map<Level, bool> defaultExcludeBoxes = {
  LoggerFactory.Level.debug: true,
  LoggerFactory.Level.info: true,
  LoggerFactory.Level.warning: true,
  // Disable boxing for all levels — box-drawing chars (┌, │, └) break the
  // date-prefix detection in getLogs() and cause error entries to be absorbed
  // into the preceding entry's body instead of starting their own record.
  LoggerFactory.Level.error: true,
  LoggerFactory.Level.trace: true,
  LoggerFactory.Level.fatal: true,
};

class BaseLogger {
  LoggerFactory.Logger _logger = LoggerFactory.Logger();

  final StreamController<String> logStream = StreamController<String>.broadcast();

  /// Each isolate logs to its own files (see [RotatingFileOutput]); main keeps the original names.
  String get _filePrefix {
    if (_isolateName == 'main') return 'bluebubbles';
    return 'bluebubbles-${_isolateName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';
  }

  // One instance per isolate: the logger is rebuilt on every settings change, and a new output each time
  // would leave the old file handle open.
  late final LoggerFactory.LogOutput fileOutput = () {
    final baseFileOutput = RotatingFileOutput(
      dirPath: logDir,
      filePrefix: _filePrefix,
      maxFileSizeKB: 1024 * 5, // 5 MB
      maxRotatedFilesCount: 5, // Per isolate: 25 MB of logs before old logs are deleted
      encoding: utf8,
    );

    // Wrap with ANSI stripper to ensure file is valid UTF-8
    return FileOutputWrapper(baseFileOutput);
  }();

  LoggerFactory.LogOutput get defaultOutput {
    List<LogOutput> outputs = kDebugMode ? [DebugConsoleOutput()] : [];
    if (!kIsWeb) outputs.add(fileOutput);
    return LoggerFactory.MultiOutput(outputs);
  }

  LoggerFactory.LogFilter? _currentFilter;
  set currentFilter(LoggerFactory.LogFilter? filter) {
    _currentFilter = filter;
    _logger = createLogger();
  }

  LoggerFactory.LogFilter get currentFilter {
    return _currentFilter ?? LoggerFactory.ProductionFilter();
  }

  LoggerFactory.LogOutput? _currentOutput;
  set currentOutput(LoggerFactory.LogOutput? output) {
    _currentOutput = output;
    _logger = createLogger();
  }

  LoggerFactory.LogOutput get currentOutput {
    return _currentOutput ?? defaultOutput;
  }

  LoggerFactory.Level? _currentLevel;
  set currentLevel(LoggerFactory.Level? level) {
    _currentLevel = level;
    info("Setting log level to $level");
    _logger = createLogger();
  }

  LoggerFactory.Level? get currentLevel {
    return _currentLevel ?? LoggerFactory.Level.info;
  }

  bool? _showColors;
  set showColors(bool show) {
    _showColors = show;
    _logger = createLogger();
  }

  bool get showColors {
    return _showColors ?? kDebugMode;
  }

  Map<Level, bool>? _excludeBoxes;
  set excludeBoxes(Map<Level, bool> boxes) {
    _excludeBoxes = boxes;
    _logger = createLogger();
  }

  Map<Level, bool> get excludeBoxes {
    return _excludeBoxes ?? defaultExcludeBoxes;
  }

  String get logDir {
    return FilesystemSvc.logsPath;
  }

  LoggerFactory.Logger get logger {
    return _logger;
  }

  String _isolateName = "main";

  Future<void> init() async {
    // Before createLogger(): the file output is named after the isolate.
    final name = isolateNameOverride ?? Isolate.current.debugName ?? "main";
    _isolateName = logNamePrefix == null ? name : (name == "main" ? logNamePrefix! : "$logNamePrefix$name");
    _logger = createLogger();

    if (SettingsSvc.initCompleted.isCompleted) {
      currentLevel = SettingsSvc.settings.logLevel.value;
    } else {
      SettingsSvc.initCompleted.future.then((_) {
        currentLevel = SettingsSvc.settings.logLevel.value;
      });
    }

    // Add initial data to logStream
    logStream.sink.add("Logger initialized");
  }

  LoggerFactory.Logger createLogger() {
    return LoggerFactory.Logger(
      filter: currentFilter,
      printer: _MessageFirstPrinter(
        methodCount: 0,
        errorMethodCount: 25,
        lineLength: 120,
        colors: showColors,
        printEmojis: false,
        // Don't contain a timestamp, we will add it in ourselves
        dateTimeFormat: LoggerFactory.DateTimeFormat.none,
        excludeBox: excludeBoxes,
        noBoxingByDefault: true,
        levelColors: {
          Level.trace: const AnsiColor.fg(5),
          Level.debug: AnsiColor.fg(AnsiColor.grey(0.5)),
          Level.info: const AnsiColor.fg(12),
          Level.warning: const AnsiColor.fg(208),
          Level.error: const AnsiColor.fg(196),
          Level.fatal: const AnsiColor.fg(199),
        },
      ),
      output: currentOutput,
      level: currentLevel,
    );
  }

  void reset() {
    _currentFilter = null;
    _currentOutput = null;
    _currentLevel = null;
    _showColors = null;
    _excludeBoxes = null;

    if (SettingsSvc.initCompleted.isCompleted) {
      _currentLevel = SettingsSvc.settings.logLevel.value;
    }

    _logger = createLogger();
  }

  void enableLiveLogging() {
    List<LogOutput> outputs = [DebugConsoleOutput(), LogStreamOutput()];
    if (!kIsWeb) outputs.add(fileOutput);
    _currentOutput = LoggerFactory.MultiOutput(outputs);
    _showColors = false;
    _logger = createLogger();
  }

  void disableLiveLogging() {
    _currentOutput = null;
    _showColors = null;
    _logger = createLogger();
  }

  Future<String> compressLogs() async {
    try {
      final Directory logDir = Directory(Logger.logDir);
      if (!logDir.existsSync()) {
        throw Exception("Log directory does not exist");
      }

      final date = DateTime.now().toIso8601String().split('T').first;
      final File zippedLogFile = File(join(FilesystemSvc.appDocDir.path, "bluebubbles-logs-$date.zip"));
      if (zippedLogFile.existsSync()) zippedLogFile.deleteSync();

      // Skips the latest files Clear Logs emptied. .dmp files are Windows crash dumps that WER writes here.
      final List<File> logFiles = logDir
          .listSync()
          .whereType<File>()
          .where((file) => (file.path.endsWith(".log") || file.path.endsWith(".dmp")) && file.lengthSync() > 0)
          .toList();

      if (logFiles.isEmpty) {
        throw Exception("No log files found to compress");
      }

      final List<String> logPaths = logFiles.map((file) => file.path).toList();

      final encoder = ZipFileEncoder();
      encoder.create(zippedLogFile.path);
      try {
        for (final logPath in logPaths) {
          await encoder.addFile(File(logPath));
        }
        await _addMergedLog(encoder, logDir.path);
      } finally {
        await encoder.close();
      }

      return zippedLogFile.path;
    } catch (e, stackTrace) {
      error("Failed to compress logs", error: e, trace: stackTrace);
      rethrow;
    }
  }

  Future<List<String>> getLogs({int maxLines = 1000}) async {
    try {
      final Directory logDir = Directory(Logger.logDir);
      if (!logDir.existsSync()) return [];

      // Each isolate has its own latest file; merge them back into one timeline.
      final latestFiles = logDir.listSync().whereType<File>().where((f) => f.path.endsWith('-latest.log'));
      final entries = [
        for (final file in latestFiles)
          for (final entry in await _readTailEntries(file, maxLines)) (_entryTime(entry), entry),
      ];
      // Stable, so entries with the same timestamp keep their order within a file.
      mergeSort(entries, compare: (a, b) => a.$1.compareTo(b.$1));
      final logs = entries.map((e) => e.$2).toList();
      return logs.length > maxLines ? logs.sublist(logs.length - maxLines) : logs;
    } catch (e, stackTrace) {
      debugPrint('Error reading logs: $e\n$stackTrace');
      return [];
    }
  }

  /// Adds every log file merged into one timeline, since the per-isolate files are hard to follow on their own.
  /// Best-effort: the raw files are already in the zip, so a failed merge leaves it out rather than failing the export.
  Future<void> _addMergedLog(ZipFileEncoder encoder, String logDir) async {
    final File mergedFile = File(join(FilesystemSvc.appDocDir.path, "bluebubbles-merged.log"));
    try {
      await _writeMergedLogInIsolate(logDir, mergedFile.path);
      await encoder.addFile(mergedFile);
    } catch (e, stackTrace) {
      warn("Leaving the merged log out of the export", error: e, trace: stackTrace);
    } finally {
      try {
        if (mergedFile.existsSync()) mergedFile.deleteSync();
      } catch (_) {}
    }
  }

  /// How long the merge gets before it's killed and left out of the export.
  static const Duration _mergeTimeout = Duration(minutes: 2);

  /// Runs [_writeMergedLog] in a short-lived isolate of its own, which exits once it's done. The merge reads every
  /// log file and needs nothing but their paths, so it doesn't tie up the UI or depend on the GlobalIsolate.
  /// Throws a [TimeoutException] after [_mergeTimeout], once the isolate is killed.
  ///
  /// Static, with only value parameters, so the entry point can't capture `this` and its unsendable stream (see
  /// ChatStatsController's isolate entry points).
  static Future<void> _writeMergedLogInIsolate(String logDir, String outPath) async {
    final port = ReceivePort();
    final Isolate isolate;
    try {
      isolate = await Isolate.spawn(_mergeLogEntry, (port.sendPort, logDir, outPath),
          onExit: port.sendPort, debugName: 'LogExport');
    } catch (_) {
      port.close();
      rethrow;
    }
    // The entry point's result, or the onExit null if the isolate died first.
    final result = port.first;
    final Object? message;
    try {
      message = await result.timeout(_mergeTimeout);
    } on TimeoutException {
      isolate.kill(priority: Isolate.immediate);
      // Wait for it to exit, so the caller can delete the half-written file.
      await result.timeout(const Duration(seconds: 5), onTimeout: () => null);
      rethrow;
    }
    if (message is (String, String)) throw RemoteError(message.$1, message.$2);
    if (message != true) throw StateError("The log merge isolate exited without finishing");
  }

  /// The merge isolate's entry point: reports `true` on success, or the error and stack trace as strings.
  static Future<void> _mergeLogEntry((SendPort, String, String) args) async {
    final (resultPort, logDir, outPath) = args;
    Object result = true;
    try {
      await _writeMergedLog(logDir, outPath);
    } catch (e, stackTrace) {
      result = ('$e', '$stackTrace');
    }
    Isolate.exit(resultPort, result);
  }

  /// Writes every log file in [logDir], rotated ones included, to [outPath] as one timeline. Each isolate rotates on
  /// its own schedule, so merging only the latest files would leave uneven coverage.
  ///
  /// Each writer's files are already in time order, so they're streamed oldest first and the streams merged,
  /// holding about one chunk per writer in memory rather than every file.
  static Future<void> _writeMergedLog(String logDir, String outPath) async {
    final sources = [for (final files in _logFilesByWriter(Directory(logDir))) _MergeSource(_readEntryBatches(files))];
    final sink = File(outPath).openWrite();
    try {
      for (final source in sources) {
        await source.load();
      }
      while (true) {
        // The earliest entry; ties go to the first source, so the output is deterministic.
        _MergeSource? next;
        for (final source in sources) {
          if (source.entry != null && (next == null || source.time.isBefore(next.time))) next = source;
        }
        if (next == null) break;
        sink.writeln(next.entry);
        if (!next.advanceInBatch()) {
          // Let the file catch up before reading more, so unwritten output doesn't pile up in memory.
          await sink.flush();
          await next.load();
        }
      }
    } finally {
      await sink.close();
      for (final source in sources) {
        await source.cancel();
      }
    }
  }

  /// [dir]'s log files grouped by writer (file prefix), each group oldest first: rotated files by the epoch in their
  /// name, then the latest file. A file matching neither naming pattern is a group of its own.
  static List<List<File>> _logFilesByWriter(Directory dir) {
    final latestName = RegExp(r'^(.+)-latest\.log$');
    final rotatedName = RegExp(r'^(.+)-\d{4}-\d{2}-\d{2}-(\d+)\.log$');
    final groups = <String, List<(int, File)>>{};
    for (final file in dir.listSync().whereType<File>()) {
      final name = basename(file.path);
      if (!name.endsWith('.log')) continue;
      final latest = latestName.firstMatch(name);
      final rotated = latest == null ? rotatedName.firstMatch(name) : null;
      // The latest file sorts after every rotated one.
      final order = rotated == null ? 1 << 62 : int.parse(rotated.group(2)!);
      (groups[latest?.group(1) ?? rotated?.group(1) ?? name] ??= []).add((order, file));
    }
    return [
      for (final group in groups.values) [for (final (_, file) in group..sort((a, b) => a.$1.compareTo(b.$1))) file],
    ];
  }

  /// The entries of [files], in order, as one batch per chunk read.
  static Stream<List<String>> _readEntryBatches(List<File> files) async* {
    for (final file in files) {
      // Entries never span files, so each file is joined on its own, like the tail reader does.
      final joiner = _EntryJoiner();
      // Decoded and split synchronously per chunk; a stream of lines would cost an async step per line.
      final input = const Utf8Decoder(allowMalformed: true)
          .startChunkedConversion(const LineSplitter().startChunkedConversion(joiner));
      try {
        await for (final chunk in file.openRead()) {
          input.add(chunk);
          yield joiner.take();
        }
        input.close();
      } catch (e, stackTrace) {
        debugPrint('Error reading ${file.path}: $e\n$stackTrace');
      }
      joiner.close();
      yield joiner.take();
    }
  }

  /// The last [maxLines] entries of [logFile], with multi-line entries joined.
  Future<List<String>> _readTailEntries(File logFile, int maxLines) async {
    try {
      final int fileSize = await logFile.length();
      if (fileSize == 0) return [];

      // Seek backwards to find the byte offset for the last [maxLines] entries.
      // This avoids reading the entire file into memory.
      final int startOffset = await _findTailStartOffset(logFile, fileSize, maxLines);

      // Stream only the relevant tail of the file.
      final List<String> lines = await logFile
          .openRead(startOffset)
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .toList();

      final logs = _joinEntries(lines);

      // Safety trim in case startOffset==0 and the file has more entries than maxLines.
      if (logs.length > maxLines) {
        return logs.sublist(logs.length - maxLines);
      }
      return logs;
    } catch (e, stackTrace) {
      debugPrint('Error reading ${logFile.path}: $e\n$stackTrace');
      return [];
    }
  }

  /// Combines lines that are part of the same log message.
  List<String> _joinEntries(List<String> lines) {
    final joiner = _EntryJoiner();
    lines.forEach(joiner.add);
    joiner.close();
    return joiner.take();
  }

  /// Scans [file] backwards in 64 KB chunks looking for newline bytes followed
  /// by an ASCII date prefix (`YYYY-`).  Returns the absolute byte offset of
  /// the [maxEntries]-th log-entry start from the end of the file, so callers
  /// can open a stream starting at that offset and avoid reading the entire file.
  ///
  /// Returns 0 if the file contains fewer than [maxEntries] entries.
  Future<int> _findTailStartOffset(File file, int fileSize, int maxEntries) async {
    const int chunkSize = 65536; // 64 KB
    final RandomAccessFile raf = await file.open();
    try {
      int entriesFound = 0;
      int scanPos = fileSize;
      // Holds the first few bytes of the chunk processed in the previous (rightward)
      // iteration so we can detect a date pattern that straddles a chunk boundary.
      List<int> rightBoundary = [];

      while (scanPos > 0) {
        final int readFrom = (scanPos - chunkSize).clamp(0, scanPos);
        final int length = scanPos - readFrom;

        await raf.setPosition(readFrom);
        final List<int> chunk = await raf.read(length);

        // Scan backwards through this chunk for \n followed by YYYY-.
        for (int i = chunk.length - 1; i >= 0; i--) {
          if (chunk[i] != 0x0A) continue; // not a newline

          // Collect the 5 bytes after this \n (may span into rightBoundary).
          final List<int> after;
          final int available = chunk.length - i - 1;
          if (available >= 5) {
            after = chunk.sublist(i + 1, i + 6);
          } else {
            after = [
              ...chunk.sublist(i + 1),
              ...rightBoundary.take(5 - available),
            ];
          }

          if (_isLogEntryStart(after)) {
            entriesFound++;
            if (entriesFound == maxEntries) {
              return readFrom + i + 1;
            }
          }
        }

        // Keep the leading bytes of this chunk for the next (leftward) iteration.
        rightBoundary = chunk.take(6).toList();
        scanPos = readFrom;
      }

      // Fewer entries in the file than maxEntries — read from the start.
      return 0;
    } finally {
      await raf.close();
    }
  }

  /// Returns true when [bytes] starts with the ASCII pattern for a log-entry
  /// date prefix: four decimal digits followed by a hyphen (`YYYY-`).
  bool _isLogEntryStart(List<int> bytes) {
    if (bytes.length < 5) return false;
    return bytes[0] >= 0x30 &&
        bytes[0] <= 0x39 &&
        bytes[1] >= 0x30 &&
        bytes[1] <= 0x39 &&
        bytes[2] >= 0x30 &&
        bytes[2] <= 0x39 &&
        bytes[3] >= 0x30 &&
        bytes[3] <= 0x39 &&
        bytes[4] == 0x2D; // '-'
  }

  void clearLogs() {
    try {
      final Directory logDir = Directory(Logger.logDir);
      if (!logDir.existsSync()) return;

      for (final file in logDir.listSync().whereType<File>()) {
        try {
          // Every isolate keeps its latest file open; deleting it would throw on Windows and orphan the
          // writer's handle elsewhere. Writers seek to the end, so they pick up the truncation.
          if (file.path.endsWith('-latest.log')) {
            file.writeAsBytesSync([]);
          } else {
            file.deleteSync();
          }
        } catch (e) {
          debugPrint("Error clearing ${file.path}: $e");
        }
      }
    } catch (e, stackTrace) {
      debugPrint("Error clearing logs: $e\n$stackTrace");
    }
  }

  /// Dispose of resources when the logger is no longer needed
  Future<void> dispose() async {
    await logStream.close();
    // Close the underlying logger output if needed
    await currentOutput.destroy();
  }

  void info(dynamic log, {String? tag, Object? error, StackTrace? trace}) =>
      logger.i("${DateTime.now().toUtc().toIso8601String()} [INFO] [$_isolateName] [${tag ?? "BlueBubblesApp"}] $log",
          error: error, stackTrace: trace);

  void warn(dynamic log, {String? tag, Object? error, StackTrace? trace}) =>
      logger.w("${DateTime.now().toUtc().toIso8601String()} [WARN] [$_isolateName] [${tag ?? "BlueBubblesApp"}] $log",
          error: error, stackTrace: trace);

  void debug(dynamic log, {String? tag, Object? error, StackTrace? trace}) =>
      logger.d("${DateTime.now().toUtc().toIso8601String()} [DEBUG] [$_isolateName] [${tag ?? "BlueBubblesApp"}] $log",
          error: error, stackTrace: trace);

  void error(dynamic log, {String? tag, Object? error, StackTrace? trace}) =>
      logger.e("${DateTime.now().toUtc().toIso8601String()} [ERROR] [$_isolateName] [${tag ?? "BlueBubblesApp"}] $log",
          error: error, stackTrace: trace);

  void trace(dynamic log, {String? tag, Object? error, StackTrace? trace}) =>
      logger.t("${DateTime.now().toUtc().toIso8601String()} [TRACE] [$_isolateName] [${tag ?? "BlueBubblesApp"}] $log",
          error: error ?? Traceback(), stackTrace: trace);

  void fatal(dynamic log, {String? tag, Object? error, StackTrace? trace}) =>
      logger.f("${DateTime.now().toUtc().toIso8601String()} [FATAL] [$_isolateName] [${tag ?? "BlueBubblesApp"}] $log",
          error: error, stackTrace: trace);

  void test(dynamic log, {String? tag, Object? error, StackTrace? trace}) =>
      logger.f("${DateTime.now().toUtc().toIso8601String()} [TEST] [$_isolateName] [${tag ?? "BlueBubblesApp"}] $log",
          error: error, stackTrace: trace);
}

/// A [PrettyPrinter] that prints the message before the error and stack trace rather than after them. An entry's
/// timestamp is in its message, so anything that splits the file into entries by timestamp (the log viewer, the
/// merged export) would otherwise attach the trace to the entry above, which after merging can be another isolate's.
class _MessageFirstPrinter extends LoggerFactory.PrettyPrinter {
  _MessageFirstPrinter({
    super.methodCount,
    super.errorMethodCount,
    super.lineLength,
    super.colors,
    super.printEmojis,
    super.dateTimeFormat,
    super.excludeBox,
    super.noBoxingByDefault,
    super.levelColors,
  });

  @override
  List<String> log(LogEvent event) {
    final lines = super.log(event);
    // A boxed event has borders between its sections; leave it as is.
    final boxed = !(excludeBox[event.level] ?? noBoxingByDefault);
    final message = event.message;
    if (boxed || message is! String) return lines;

    // The message is printed last, one line per line of it.
    final split = lines.length - message.split('\n').length;
    if (split <= 0) return lines;
    return [...lines.sublist(split), ...lines.sublist(0, split)];
  }
}

/// Combines lines that are part of the same log message. Lines go in through [add]; finished entries come out of
/// [take]. [close] finishes the entry in progress.
class _EntryJoiner implements Sink<String> {
  static final _dateStart = RegExp(r'^\d{4}-\d{2}-\d{2}');
  static final _ansiEscape = RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]');

  final StringBuffer _current = StringBuffer();
  List<String> _entries = [];

  /// The entries finished since the last call.
  List<String> take() {
    final entries = _entries;
    _entries = [];
    return entries;
  }

  @override
  void add(String rawLine) {
    // PrettyPrinter wraps ERROR/TRACE/FATAL entries in Unicode box borders:
    //   ┌──...  (top border — skip)
    //   │ 2024-...  (content with │ prefix — strip prefix)
    //   └──...  (bottom border — skip)
    // Stripping these allows the date-start check below to work for all levels.
    String line = rawLine.replaceAll(_ansiEscape, '');

    // Skip horizontal box border lines (┌, └, ├).
    if (line.startsWith('┌') || line.startsWith('└') || line.startsWith('├')) return;
    // Strip the vertical-bar prefix used by boxed content lines.
    if (line.startsWith('│ ')) line = line.substring(2);

    if (_dateStart.hasMatch(line)) {
      close();
      _current.write(line);
    } else if (_current.isNotEmpty) {
      _current.write('\n$line');
    }
  }

  @override
  void close() {
    if (_current.isEmpty) return;
    _entries.add(_current.toString());
    _current.clear();
  }
}

/// One writer's entries during a merge. Entries arrive in batches, so only moving past the end of a batch is
/// asynchronous.
class _MergeSource {
  _MergeSource(Stream<List<String>> batches) : _batches = StreamIterator(batches);

  final StreamIterator<List<String>> _batches;
  List<String> _batch = const [];
  int _index = 0;

  /// The current entry, null once every batch is used up.
  String? entry;

  /// The current entry's timestamp.
  DateTime time = DateTime(0);

  /// Moves to the next entry in the current batch, returning false at the end of it; then call [load].
  bool advanceInBatch() {
    if (++_index >= _batch.length) return false;
    _setEntry(_batch[_index]);
    return true;
  }

  /// Moves to the first entry of the next non-empty batch.
  Future<void> load() async {
    while (await _batches.moveNext()) {
      _batch = _batches.current;
      _index = 0;
      if (_batch.isNotEmpty) {
        _setEntry(_batch.first);
        return;
      }
    }
    entry = null;
  }

  Future<void> cancel() => _batches.cancel();

  void _setEntry(String value) {
    entry = value;
    time = _entryTime(value);
  }
}

/// The timestamp an entry starts with, or year 0 if it doesn't parse, so such entries sort first.
DateTime _entryTime(String entry) {
  final space = entry.indexOf(' ');
  return DateTime.tryParse(space < 0 ? entry : entry.substring(0, space)) ?? DateTime(0);
}

class Traceback implements Exception {
  final StackTrace? stackTrace;

  Traceback([this.stackTrace]);

  @override
  String toString() {
    return "Traceback";
  }
}
