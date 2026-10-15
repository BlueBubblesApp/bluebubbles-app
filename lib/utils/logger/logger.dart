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
      printer: LoggerFactory.PrettyPrinter(
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

      final List<FileSystemEntity> files = logDir.listSync();
      final List<FileSystemEntity> logFiles = files.where((file) => file.path.endsWith(".log")).toList();

      if (logFiles.isEmpty) {
        throw Exception("No log files found to compress");
      }

      final List<String> logPaths = logFiles.map((file) => file.path).toList();

      final encoder = ZipFileEncoder();
      encoder.create(zippedLogFile.path);
      for (final logPath in logPaths) {
        await encoder.addFile(File(logPath));
      }
      // The per-isolate files are hard to follow on their own; add every isolate's latest file merged into one timeline.
      final merged = await getLogs(maxLines: 1 << 30);
      encoder.addArchiveFile(ArchiveFile.string('bluebubbles-merged.log', '${merged.join('\n')}\n'));
      await encoder.close();

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
          for (final entry in await _readTailEntries(file, maxLines))
            (DateTime.tryParse(entry.split(' ').first) ?? DateTime(0), entry),
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

      // Combine lines that are part of the same log message.
      // PrettyPrinter wraps ERROR/TRACE/FATAL entries in Unicode box borders:
      //   ┌──...  (top border — skip)
      //   │ 2024-...  (content with │ prefix — strip prefix)
      //   └──...  (bottom border — skip)
      // Stripping these allows the date-start check below to work for all levels.
      final List<String> logs = [];
      String currentLog = '';
      final dateStart = RegExp(r'^\d{4}-\d{2}-\d{2}');
      for (final rawLine in lines) {
        String line = rawLine.replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '');

        // Skip horizontal box border lines (┌, └, ├).
        if (line.startsWith('┌') || line.startsWith('└') || line.startsWith('├')) continue;
        // Strip the vertical-bar prefix used by boxed content lines.
        if (line.startsWith('│ ')) line = line.substring(2);

        if (dateStart.hasMatch(line)) {
          if (currentLog.isNotEmpty) logs.add(currentLog);
          currentLog = line;
        } else if (currentLog.isNotEmpty) {
          currentLog += '\n$line';
        }
      }
      if (currentLog.isNotEmpty) logs.add(currentLog);

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

class Traceback implements Exception {
  final StackTrace? stackTrace;

  Traceback([this.stackTrace]);

  @override
  String toString() {
    return "Traceback";
  }
}
