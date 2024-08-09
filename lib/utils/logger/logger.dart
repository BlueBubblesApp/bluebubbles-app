import 'package:archive/archive_io.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:universal_io/io.dart';

// ignore: library_prefixes
import 'package:logger/logger.dart' as LoggerFactory;

import 'outputs/debug_console_output.dart';

// ignore: non_constant_identifier_names
BaseLogger Logger = Get.isRegistered<BaseLogger>() ? Get.find<BaseLogger>() : Get.put(BaseLogger());

enum LogLevel { INFO, WARN, ERROR, DEBUG, TRACE, FATAL }

class BaseLogger extends GetxService {
  late final LoggerFactory.Logger logger;

  String get logDir {
    return join(fs.appDocDir.path, 'logs');
  }

  Future<void> init() async {
    logger = createLogger(filter: LoggerFactory.ProductionFilter());
  }

  LoggerFactory.Logger createLogger({required LoggerFactory.LogFilter filter}) {
    return LoggerFactory.Logger(
      filter: filter,
      printer: LoggerFactory.PrettyPrinter(
        methodCount: 0, // Number of method calls to be displayed for any logs
        errorMethodCount: 8, // Number of method calls if stacktrace is provided
        lineLength: 120, // Width of the output
        colors: kDebugMode, // Colorful log messages
        printEmojis: true, // Print an emoji for each log message
        // Should each log print contain a timestamp
        dateTimeFormat: LoggerFactory.DateTimeFormat.dateAndTime,
        excludeBox: {
          LoggerFactory.Level.debug: true,
          LoggerFactory.Level.info: true,
          LoggerFactory.Level.warning: true,
          LoggerFactory.Level.error: false,
          LoggerFactory.Level.trace: false,
          LoggerFactory.Level.fatal: false,
        }
      ),
      output: LoggerFactory.MultiOutput([
        DebugConsoleOutput(),
        LoggerFactory.AdvancedFileOutput(
          path: logDir,
          maxFileSizeKB: 1024 * 10,  // 10MB
          maxRotatedFilesCount: 5,
          maxDelay: const Duration(seconds: 3),
          latestFileName: 'bluebubbles-latest.log',
          fileNameFormatter: (timestamp) {
            final now = DateTime.now();
            return 'bluebubbles-${now.toIso8601String().split('T').first}-${now.millisecondsSinceEpoch ~/ 1000}.log';
          },
        )
      ]),
    );
  }

  set logFilter(LoggerFactory.LogFilter filter) {
    logger = createLogger(filter: filter);
  }

  void setToDevelopment() {
    logFilter = LoggerFactory.DevelopmentFilter();
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
