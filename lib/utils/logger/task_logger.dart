import 'package:async_task/async_task.dart';
import 'package:bluebubbles/utils/logger/logger.dart';

AsyncTaskLogger asyncTaskLogger = (String type, dynamic message, [dynamic error, dynamic stackTrace]) {
  if (type == 'ERROR') {
    Logger.error(message, error: error, trace: stackTrace);
  } else if (type == 'WARN') {
    Logger.warn(message, error: error, trace: stackTrace);
  } else {
    // type == EXEC OR INFO
    Logger.debug(message, error: error, trace: stackTrace);
  }
};