import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';

/// The alarm manager is responsible for all scheduled events
///
/// All scheduling is handled through native java code
class AlarmManager {
  factory AlarmManager() {
    return _manager;
  }

  static final AlarmManager _manager = AlarmManager._internal();

  AlarmManager._internal();

  /// Sets an alarm at a specified [DateTime]
  /// @param [id] is an identifier for a particular alarm. This would be saved to disk,
  /// and then when an alarm is needed, using the id it is retreived from disk and the action is executed
  Future<void> setAlarm(int id, DateTime dateTime) async {
    await MethodChannelInterface()
        .invokeMethod("schedule-alarm", {"id": id, "milliseconds": dateTime.millisecondsSinceEpoch});
  }

  /// Defines what to do when a specific alarm goes off
  /// @param [id] is the id of the alarm
  void onReceiveAlarm(int id) {
    Logger.info("Receive alarm $id", tag: "AlarmManager");

    // Keep this just in case the thread doesn't get closed automatically from the socket events sent
    MethodChannelInterface().closeThread();
  }
}
