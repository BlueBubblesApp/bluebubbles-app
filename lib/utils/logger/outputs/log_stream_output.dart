import 'package:logger/logger.dart';

// ignore: library_prefixes
import 'package:bluebubbles/utils/logger/logger.dart' as BlueBubblesLogger;


class LogStreamOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    return BlueBubblesLogger.Logger.logStream.sink.add(event.lines.join('\n'));
  }
}
