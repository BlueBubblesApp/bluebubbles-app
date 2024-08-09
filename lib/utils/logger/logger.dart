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
BaseLogger Logger = Get.isRegistered<BaseLogger>() ? Get.find<BaseLogger>() : Get.put(BaseLogger());

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

  final StreamController<String> logStream = StreamController<String>.broadcast();

  String get logDir {
    return join(fs.appDocDir.path, 'logs');
  }

  LoggerFactory.Logger get logger {
    return _logger;
  }

  LoggerFactory.LogOutput get fileOutput {
    return LoggerFactory.AdvancedFileOutput(
      path: logDir,
      maxFileSizeKB: 1024 * 10,  // 10MB
      maxRotatedFilesCount: 5,
      maxDelay: const Duration(seconds: 3),
      latestFileName: 'bluebubbles-latest.log',
      fileNameFormatter: (timestamp) {
        final now = DateTime.now();
        return 'bluebubbles-${now.toIso8601String().split('T').first}-${now.millisecondsSinceEpoch ~/ 1000}.log';
      }
    );
  }

  LoggerFactory.LogOutput get defaultOutput {
    return LoggerFactory.MultiOutput([
      DebugConsoleOutput(),
      fileOutput
    ]);
  }

  Future<void> init() async {
    setToProduction();
    
    // Add initial data to logStream
    logStream.sink.add("Logger initialized");
  }

  LoggerFactory.Logger createLogger({
    required LoggerFactory.LogFilter filter,
    required LoggerFactory.LogOutput output,
    bool colors = kDebugMode,
    Map<Level, bool> excludeBoxes = defaultExcludeBoxes
  }) {
    return LoggerFactory.Logger(
      filter: filter,
      printer: LoggerFactory.PrettyPrinter(
        methodCount: 0, // Number of method calls to be displayed for any logs
        errorMethodCount: 8, // Number of method calls if stacktrace is provided
        lineLength: 120, // Width of the output
        colors: colors, // Colorful log messages
        printEmojis: false, // Print an emoji for each log message
        // Should each log print contain a timestamp
        dateTimeFormat: LoggerFactory.DateTimeFormat.dateAndTime,
        excludeBox: excludeBoxes,
        noBoxingByDefault: true,
      ),
      output: output,
    );
  }

  set logFilter(LoggerFactory.LogFilter filter) {
    _logger = createLogger(filter: filter, output: defaultOutput);
  }

  void setToDevelopment() {
    _logger = createLogger(
      filter: LoggerFactory.DevelopmentFilter(),
      output: defaultOutput
    );
  }

  void setToProduction() {
    _logger = createLogger(
      filter: LoggerFactory.ProductionFilter(),
      output: defaultOutput
    );
  }

  void enableLiveLogging() {
    _logger = createLogger(
      filter: LoggerFactory.ProductionFilter(),
      output: LoggerFactory.MultiOutput([
        DebugConsoleOutput(),
        fileOutput,
        LogStreamOutput()
      ]),
      colors: false,
      excludeBoxes: const {}
    );
  }

  void disableLiveLogging() {
    setToProduction();
  }

  String compressLogs() {
    final Directory logDir = Directory(Logger.logDir);
    final date = DateTime.now().toIso8601String().split('T').first;
    final File zippedLogFile = File("${fs.appDocDir.path}/bluebubbles-logs-$date.zip");
    if (zippedLogFile.existsSync()) zippedLogFile.deleteSync();

    final List<FileSystemEntity> files = logDir.listSync();
    final List<FileSystemEntity> logFiles = files.where((file) => file.path.endsWith(".log")).toList();
    final List<String> logPaths = logFiles.map((file) => file.path).toList();

    final encoder = ZipFileEncoder();
    encoder.create(zippedLogFile.path);
    for (final logPath in logPaths) {
      encoder.addFile(File(logPath));
    }
    encoder.close();

    return zippedLogFile.path;
  }

  void info(dynamic log, {String? tag, Object? error, StackTrace? trace}) => logger.i("[${tag ?? "BlueBubblesApp"}] $log", error: error, stackTrace: trace);

  void warn(dynamic log, {String? tag, Object? error, StackTrace? trace}) => logger.w("[${tag ?? "BlueBubblesApp"}] $log", error: error, stackTrace: trace);

  void debug(dynamic log, {String? tag, Object? error, StackTrace? trace}) => logger.d("[${tag ?? "BlueBubblesApp"}] $log", error: error, stackTrace: trace);

  void error(dynamic log, {String? tag, Object? error, StackTrace? trace}) => logger.e("[${tag ?? "BlueBubblesApp"}] $log", error: error, stackTrace: trace);

  void trace(dynamic log, {String? tag, Object? error, StackTrace? trace}) => logger.t("[${tag ?? "BlueBubblesApp"}] $log", error: error, stackTrace: trace);

  void fatal(dynamic log, {String? tag, Object? error, StackTrace? trace}) => logger.f("[${tag ?? "BlueBubblesApp"}] $log", error: error, stackTrace: trace);
}
