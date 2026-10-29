import 'package:bluebubbles/env.dart';
import 'package:bluebubbles/models/parsed_log_entry.dart';
import 'package:bluebubbles/services/backend/actions/log_actions.dart';
import 'package:bluebubbles/services/isolates/global_isolate.dart';
import 'package:get_it/get_it.dart';

class LogInterface {
  /// Returns the last [maxLines] log entries as parsed [ParsedLogEntry] objects.
  ///
  /// All file I/O and string parsing runs in the [GlobalIsolate]; only the
  /// compact structured data crosses the isolate boundary.  Filtering by log
  /// level should be done on the caller side using [ParsedLogEntry.level] so
  /// that changing filter settings does not require re-reading from disk.
  static Future<List<ParsedLogEntry>> getLogs({int maxLines = 500}) async {
    final data = {'maxLines': maxLines};
    final List<dynamic> raw;
    if (isIsolate) {
      raw = await LogActions.getLogs(data);
    } else {
      raw = await GetIt.I<GlobalIsolate>().send<List<dynamic>>(
        IsolateRequestType.getLogs,
        input: data,
      );
    }
    return raw.map((e) => ParsedLogEntry.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }
}
