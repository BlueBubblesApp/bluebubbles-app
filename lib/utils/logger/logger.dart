import 'dart:async';

import 'package:archive/archive_io.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/outputs/log_stream_output.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:universal_io/io.dart';

// ignore: library_prefixes
import 'package:logger/logger.dart' as LoggerFactory;

import 'outputs/debug_console_output.dart';

// ignore: non_constant_identifier_names
BaseLogger Logger = Get.isRegistered<BaseLogger>()
    ? Get.find<BaseLogger>()
    : Get.put(BaseLogger());

enum LogLevel { INFO, WARN, ERROR, DEBUG, TRACE, FATAL }

const Map<Level, bool> defaultExcludeBoxes = {
  LoggerFactory.Level.debug: true,
  LoggerFactory.Level.info: true,
  LoggerFactory.Level.warning: true,
  LoggerFactory.Level.error: false,
  LoggerFactory.Level.trace: false,
  LoggerFactory.Level.fatal: false,
};

class BaseLogger extends GetxService {
  LoggerFactory.Logger _logger = LoggerFactory.Logger();

  final StreamController<String> logStream =
      StreamController<String>.broadcast();
  final latestLogName = 'bluebubbles-latest.log';

  LoggerFactory.LogOutput get fileOutput {
    return LoggerFactory.AdvancedFileOutput(
        path: logDir,
        maxFileSizeKB: 1024, // 1 MB
        maxRotatedFilesCount: 5,
        maxDelay: const Duration(seconds: 5),
        latestFileName: latestLogName,
        fileNameFormatter: (timestamp) {
          final now = DateTime.now();
          return 'bluebubbles-${now.toIso8601String().split('T').first}-${now.millisecondsSinceEpoch ~/ 1000}.log';
        });
  }

  LoggerFactory.LogOutput get defaultOutput {
    List<LogOutput> outputs = [DebugConsoleOutput()];
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
    return join(fs.appDocDir.path, 'logs');
  }

  LoggerFactory.Logger get logger {
    return _logger;
  }

  Future<void> init() async {
    _logger = createLogger();

    if (ss.initCompleted.isCompleted) {
      currentLevel = ss.settings.logLevel.value;
    } else {
      ss.initCompleted.future.then((_) {
        currentLevel = ss.settings.logLevel.value;
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
        errorMethodCount: 10,
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

    if (ss.initCompleted.isCompleted) {
      _currentLevel = ss.settings.logLevel.value;
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

  String compressLogs() {
    final Directory logDir = Directory(Logger.logDir);
    final date = DateTime.now().toIso8601String().split('T').first;
    final File zippedLogFile =
        File("${fs.appDocDir.path}/bluebubbles-logs-$date.zip");
    if (zippedLogFile.existsSync()) zippedLogFile.deleteSync();

    final List<FileSystemEntity> files = logDir.listSync();
    final List<FileSystemEntity> logFiles =
        files.where((file) => file.path.endsWith(".log")).toList();
    final List<String> logPaths = logFiles.map((file) => file.path).toList();

    final encoder = ZipFileEncoder();
    encoder.create(zippedLogFile.path);
    for (final logPath in logPaths) {
      encoder.addFile(File(logPath));
    }
    encoder.close();

    return zippedLogFile.path;
  }

  Future<List<String>> getLogs({maxLines = 1000}) async {
    final Directory logDir = Directory(Logger.logDir);
    if (!logDir.existsSync()) return [];

    final List<FileSystemEntity> files = logDir.listSync();
    final List<FileSystemEntity> logFiles =
        files.where((file) => file.path.endsWith(latestLogName)).toList();
    if (logFiles.isEmpty) return [];

    final File logFile = logFiles.first as File;
    final List<String> lines = await logFile.readAsLines();
    return lines.sublist(0, lines.length > maxLines ? maxLines : lines.length);
  }

  void clearLogs() {
    final Directory logDir = Directory(Logger.logDir);
    if (!logDir.existsSync()) return;

    for (final file in logDir.listSync()) {
      if (file is File) {
        file.deleteSync();
      }
    }
  }

  void info(dynamic log, {String? tag, Object? error, StackTrace? trace}) =>
      logger.i(
          "${DateTime.now().toUtc().toIso8601String()} [INFO] [${tag ?? "BlueBubblesApp"}] $log",
          error: error,
          stackTrace: trace);

  void warn(dynamic log, {String? tag, Object? error, StackTrace? trace}) =>
      logger.w(
          "${DateTime.now().toUtc().toIso8601String()} [WARN] [${tag ?? "BlueBubblesApp"}] $log",
          error: error,
          stackTrace: trace);

  void debug(dynamic log, {String? tag, Object? error, StackTrace? trace}) =>
      logger.d(
          "${DateTime.now().toUtc().toIso8601String()} [DEBUG] [${tag ?? "BlueBubblesApp"}] $log",
          error: error,
          stackTrace: trace);

  void error(dynamic log, {String? tag, Object? error, StackTrace? trace}) =>
      logger.e(
          "${DateTime.now().toUtc().toIso8601String()} [ERROR] [${tag ?? "BlueBubblesApp"}] $log",
          error: error,
          stackTrace: trace);

  void trace(dynamic log, {String? tag, Object? error, StackTrace? trace}) =>
      logger.t(
          "${DateTime.now().toUtc().toIso8601String()} [TRACE] [${tag ?? "BlueBubblesApp"}] $log",
          error: error ?? Traceback(),
          stackTrace: trace);

  void fatal(dynamic log, {String? tag, Object? error, StackTrace? trace}) =>
      logger.f(
          "${DateTime.now().toUtc().toIso8601String()} [FATAL] [${tag ?? "BlueBubblesApp"}] $log",
          error: error,
          stackTrace: trace);
}

class Traceback implements Exception {
  final StackTrace? stackTrace;

  Traceback([this.stackTrace]);

  @override
  String toString() {
    return "Traceback";
  }
}