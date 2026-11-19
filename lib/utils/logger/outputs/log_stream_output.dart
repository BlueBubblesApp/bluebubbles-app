import 'package:bluebubbles/helpers/network/url_utils.dart';
import 'package:logger/logger.dart';

// ignore: library_prefixes
import 'package:bluebubbles/utils/logger/logger.dart' as BlueBubblesLogger;

class LogStreamOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    return BlueBubblesLogger.Logger.logStream.sink.add(maskUrlPassword(event.lines.join('\n')));
  }
}
