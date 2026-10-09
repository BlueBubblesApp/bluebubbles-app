import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

mixin ScheduledMessagesMixin<T extends StatefulWidget> on State<T> {
  final RxList<ScheduledMessage> scheduled = <ScheduledMessage>[].obs;
  final Rx<bool?> fetching = Rx<bool?>(true);

  List<ScheduledMessage> get oneTime =>
      scheduled.where((e) => e.schedule.type == "once" && e.status == "pending").toList();

  List<ScheduledMessage> get recurring => scheduled.where((e) => e.schedule.type == "recurring").toList();

  List<ScheduledMessage> get oneTimeCompleted =>
      scheduled.where((e) => e.schedule.type == "once" && e.status != "pending").toList();

  DateTime? get nextScheduled {
    final pending = scheduled.where((e) => e.status == "pending" && e.scheduledFor.isAfter(DateTime.now())).toList();
    if (pending.isEmpty) return null;
    pending.sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    return pending.first.scheduledFor;
  }

  void initScheduled() {
    getExistingMessages();
  }

  void getExistingMessages() async {
    final response = await HttpSvc.message.getScheduled().catchError((_) {
      if (mounted) fetching.value = null;
      return Response(requestOptions: RequestOptions(path: ''));
    });
    if (response.statusCode == 200 && response.data['data'] != null) {
      scheduled.value =
          (response.data['data'] as List).map((e) => ScheduledMessage.fromJson(e)).toList().cast<ScheduledMessage>();
      fetching.value = false;
    }
  }

  void deleteMessage(ScheduledMessage item) async {
    final response = await HttpSvc.message.deleteScheduled(item.id);
    if (response.statusCode == 200) {
      scheduled.remove(item);
    } else {
      Logger.error(response.data);
      showSnackbar("Error", "Something went wrong!", type: SnackbarType.error);
    }
  }

  Widget buildStatusBadge(String status, BuildContext context) {
    final Color color;
    final String label;
    switch (status) {
      case "sent":
        color = Colors.green;
        label = "SENT";
        break;
      case "error":
        color = context.theme.colorScheme.error;
        label = "ERROR";
        break;
      default:
        color = context.theme.colorScheme.primary;
        label = "PENDING";
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
