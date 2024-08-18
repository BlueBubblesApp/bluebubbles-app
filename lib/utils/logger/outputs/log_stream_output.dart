import 'package:logger/logger.dart';

// ignore: library_prefixes
import 'package:bluebubbles/utils/logger/logger.dart' as BlueBubblesLogger;


class LogStreamOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    List<String> lines = List.from(event.lines);

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
        // If there is no trace, (so we are using the current trace),
        // we need to omit the first 5 lines of the trace, as they are
        // part of the logger itself.
        List<String> traceLines = traceStr.split('\n').where((txt) => txt != '<asynchronous suspension>').toList();
        if (!hasTrace) {
          traceLines = traceLines.sublist(5);
        }

        traceLines = (traceLines.length > 4) ? traceLines.sublist(0, 4) : traceLines;
        traceStr = traceLines.map((e) => e).join('\n');

        // Insert the trace into the box
        lines.add('');
        lines.add('Traceback:');
        lines.add(traceStr);
      }

      lines[0] = '[${event.level.name.toUpperCase()}] ${lines[1]}';
      lines.removeAt(1);

      // Add the level to the date entry
      // lines[1] = '${lines[1]} [${event.level.name.toUpperCase()}]';
      return BlueBubblesLogger.Logger.logStream.sink.add(lines.join('\n'));
    }

    // Remove the first item (date)
    lines.removeAt(0);

    // If it's just a single-line log, print it as a single line.
    // If there are multiple lines, print it as a block.
    if (lines.length == 1) {
      BlueBubblesLogger.Logger.logStream.sink.add("[${event.level.name.toUpperCase()}] ${lines.first}");
    } else {
      BlueBubblesLogger.Logger.logStream.sink.add("[${event.level.name.toUpperCase()}] ->\n${lines.join('\n')}");
    }
  }
}
