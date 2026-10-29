import 'package:bluebubbles/models/parsed_log_entry.dart';
import 'package:bluebubbles/utils/logger/logger.dart';

class LogActions {
  /// Reads the last [maxLines] log entries from disk, parses each into a
  /// structured map (timestamp, integer level, body) and returns the list.
  /// All heavy I/O and string processing happens here in the isolate so the
  /// main thread only receives compact, already-classified data.
  static Future<List<Map<String, dynamic>>> getLogs(Map<String, dynamic> data) async {
    final int maxLines = data['maxLines'] as int? ?? 500;
    final lines = await Logger.getLogs(maxLines: maxLines);
    return lines.map(_parseEntry).toList();
  }

  static Map<String, dynamic> _parseEntry(String entry) {
    // Each entry is a full log record, possibly multi-line (stack traces etc.).
    // Format of the first line:
    //   "2024-01-15T10:30:45.123Z [LEVEL] [isolate] [tag] message"
    final int newlineIdx = entry.indexOf('\n');
    final String firstLine = newlineIdx >= 0 ? entry.substring(0, newlineIdx) : entry;

    // Split off the leading timestamp token.
    final int spaceIdx = firstLine.indexOf(' ');
    final String timestamp = spaceIdx > 0 ? firstLine.substring(0, spaceIdx) : '';
    final String firstBody = spaceIdx > 0 ? firstLine.substring(spaceIdx + 1).trim() : firstLine.trim();

    // Reconstruct full body: first-line body + any continuation lines.
    final String continuation = newlineIdx >= 0 ? entry.substring(newlineIdx) : '';
    final String body = firstBody + continuation;

    // Classify level by checking the start of the first-line body.
    // Using startsWith (not contains) since the level tag is always first.
    final int level;
    if (firstBody.startsWith('[INFO]')) {
      level = ParsedLogEntry.info;
    } else if (firstBody.startsWith('[DEBUG]') || firstBody.startsWith('[TEST]')) {
      level = ParsedLogEntry.debug;
    } else if (firstBody.startsWith('[WARN]')) {
      level = ParsedLogEntry.warn;
    } else if (firstBody.startsWith('[ERROR]')) {
      level = ParsedLogEntry.error;
    } else if (firstBody.startsWith('[TRACE]')) {
      level = ParsedLogEntry.trace;
    } else if (firstBody.startsWith('[FATAL]')) {
      level = ParsedLogEntry.fatal;
    } else {
      level = ParsedLogEntry.unknown;
    }

    return ParsedLogEntry(timestamp: timestamp, level: level, body: body).toMap();
  }
}
