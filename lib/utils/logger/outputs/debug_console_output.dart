import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';


class DebugConsoleOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // For "boxed" logs, print them as-is.
    // For not-boxed logs, print them as a single line.
    if ([Level.fatal, Level.error, Level.trace].contains(event.level)) {
      StackTrace? trace = event.origin.stackTrace;
      bool hasTrace = trace != null && trace.toString().isNotEmpty;
      if (!hasTrace) {
        trace = StackTrace.current;
      }

      String traceStr = trace.toString();

      // Only take the last 3 lines of the trace
      if (traceStr.trim().isNotEmpty) {
        // Color logs red in debug mode
        const colorPrefix = (kDebugMode) ? '\x1B[38;5;196m' : '';

        // If there is no trace, (so we are using the current trace),
        // we need to omit the first 5 lines of the trace, as they are
        // part of the logger itself.
        List<String> traceLines = traceStr.split('\n');
        if (!hasTrace) {
          traceLines = traceLines.sublist(5);
        }

        traceLines = (traceLines.length > 4) ? traceLines.sublist(0, 4) : traceLines;
        traceStr = traceLines.map((e) => '$colorPrefix| $e').join('\n');

        // Insert the trace into the box
        event.lines.insert(event.lines.length - 1, '$colorPrefix|');
        event.lines.insert(event.lines.length - 1, '$colorPrefix| Traceback:');
        event.lines.insert(event.lines.length - 1, '$colorPrefix$traceStr');
      }

      return event.lines.forEach(debugPrint);
    }

    // Pull out and remove the first item (date)
    final date = event.lines.removeAt(0);

    // If it's just a single-line log, print it as a single line.
    // If there are multiple lines, print it as a block.
    if (event.lines.length == 1) {
      debugPrint("$date ${event.lines.first}");
    } else {
      debugPrint("$date ->\n${event.lines.join('\n')}");
    }
  }
}
