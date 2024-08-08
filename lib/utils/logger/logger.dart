import 'package:bluebubbles/services/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';

import 'outputs/debug_console_output.dart';

// ignore: library_prefixes
import 'package:logger/logger.dart' as LoggerFactory;

// ignore: non_constant_identifier_names
BaseLogger Logger = Get.isRegistered<BaseLogger>() ? Get.find<BaseLogger>() : Get.put(BaseLogger());

enum LogLevel { INFO, WARN, ERROR, DEBUG, TRACE, FATAL }

class BaseLogger extends GetxService {
  late final LoggerFactory.Logger logger;
  final logName = "bluebubbles.log";

  String get logDir {
    return join(fs.appDocDir.path, 'logs');
  }

  Future<void> init({bool isStartup = false}) async {
    logger = createLogger(filter: LoggerFactory.ProductionFilter());
  }

  LoggerFactory.Logger createLogger({required LoggerFactory.LogFilter filter}) {
    return LoggerFactory.Logger(
      filter: filter,
      printer: LoggerFactory.PrettyPrinter(
        methodCount: 0, // Number of method calls to be displayed for any logs
        errorMethodCount: 8, // Number of method calls if stacktrace is provided
        lineLength: 120, // Width of the output
        colors: true, // Colorful log messages
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
      ), // Use the PrettyPrinter to format and print log
      output: LoggerFactory.MultiOutput([
        DebugConsoleOutput(),
        LoggerFactory.AdvancedFileOutput(
          path: logDir,
          maxFileSizeKB: 1024 * 10,  // 10MB
          maxRotatedFilesCount: 5,
          maxDelay: const Duration(seconds: 3)
        )
      ]), // Use the default LogOutput (-> send everything to console)
    );
  }

  set logFilter(LoggerFactory.LogFilter filter) {
    logger = createLogger(filter: filter);
  }

  void setToDevelopment() {
    logFilter = LoggerFactory.DevelopmentFilter();
  }

  Future<void> writeLogToFile() async {
    // // Create the log file and write to it
    // if (kIsWeb) {
    //   final bytes = utf8.encode(logs.join('\n'));
    //   final content = base64.encode(bytes);
    //   html.AnchorElement(href: "data:application/octet-stream;charset=utf-16le;base64,$content")
    //     ..setAttribute("download", basename(logPath))
    //     ..click();
    //   return;
    // }
    // String filePath = logPath;
    // if (kIsDesktop) {
    //   filePath = fs.appDocDir.path;
    //   DateTime now = DateTime.now().toLocal();
    //   filePath = join(filePath, "Saved Logs",
    //       "BlueBubbles_Logs_${now.year}-${now.month}-${now.day}_${now.hour}-${now.minute}-${now.second}.txt");
    // }
    // File file = File(filePath);
    // file.createSync(recursive: true);
    // file.writeAsStringSync(logs.join('\n'));

    // // Show the snackbar when finished
    // showSnackbar(
    //   "Success",
    //   "Logs exported successfully${kIsDesktop ? "" : " to $filePath"}",
    //   durationMs: 2500,
    //   button: kIsDesktop || kIsWeb
    //       ? null
    //       : TextButton(
    //           style: TextButton.styleFrom(
    //             backgroundColor: Get.theme.colorScheme.surfaceVariant,
    //           ),
    //           onPressed: () {
    //             Share.file("BlueBubbles Logs", filePath);
    //           },
    //           child: Text("SHARE", style: TextStyle(color: Get.theme.colorScheme.onSurfaceVariant)),
    //         ),
    // );
  }

  void info(dynamic log, {String? tag, Object? error, StackTrace? trace}) => logger.i("[${tag ?? "BlueBubblesApp"}] $log", error: error, stackTrace: trace);

  void warn(dynamic log, {String? tag, Object? error, StackTrace? trace}) => logger.w("[${tag ?? "BlueBubblesApp"}] $log", error: error, stackTrace: trace);

  void debug(dynamic log, {String? tag, Object? error, StackTrace? trace}) => logger.d("[${tag ?? "BlueBubblesApp"}] $log", error: error, stackTrace: trace);

  void error(dynamic log, {String? tag, Object? error, StackTrace? trace}) => logger.e("[${tag ?? "BlueBubblesApp"}] $log", error: error, stackTrace: trace);

  void trace(dynamic log, {String? tag, Object? error, StackTrace? trace}) => logger.t("[${tag ?? "BlueBubblesApp"}] $log", error: error, stackTrace: trace);

  void fatal(dynamic log, {String? tag, Object? error, StackTrace? trace}) => logger.f("[${tag ?? "BlueBubblesApp"}] $log", error: error, stackTrace: trace);
}
