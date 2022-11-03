import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/helpers/types/helpers/message_helper.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SyncDialog extends StatefulWidget {
  SyncDialog({Key? key}) : super(key: key);

  @override
  State<SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends OptimizedState<SyncDialog> {
  String? message;
  double? progress;
  Duration lookback = Duration(days: 1);
  int page = 0;

  void syncMessages() async {
    DateTime now = DateTime.now().toUtc().subtract(lookback);
    MessagesService.getMessages(withChats: true, withAttachments: true, withHandles: true, after: now.millisecondsSinceEpoch, limit: 100).then((dynamic messages) {
      if (mounted) {
        setState(() {
          message = "Adding ${messages.length} messages...";
        });
      }

      MessageHelper.bulkAddMessages(null, messages, onProgress: (int progress, int length) {
        if (progress == 0 || length == 0) {
          this.progress = null;
        } else {
          this.progress = progress / length;
        }

        if (mounted) {
          setState(() {
            message = "Adding $progress of $length (${((this.progress ?? 0) * 100).floor().toInt()}%)";
          });
        }
      }).then((List<Message> items) {
        onFinish(true, items.length);
      });
    }).catchError((_) {
      onFinish(false, 0);
    });
  }

  void onFinish([bool success = true, int? total]) {
    if (!mounted) return;
    progress = 100;
    if (success) {
      message = "Finished adding $total messages!";
    } else {
      message = "Something went wrong";
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    String title = message ?? "";
    Widget content;
    List<Widget> actions;

    if (page == 0) {
      title = "How far back would you like to go?";
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              "Days: ${lookback.inDays}",
              style: context.theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Slider(
              value: lookback.inDays.toDouble(),
              onChanged: (double value) {
                if (!mounted) return;

                setState(() {
                  lookback = Duration(days: value.toInt());
                });
              },
              label: lookback.inDays.toString(),
              divisions: 29,
              min: 1,
              max: 30,
            ),
          )
        ],
      );

      actions = [
        TextButton(
          onPressed: () {
            if (!mounted) return;
            page = 1;
            message = "Fetching messages...";
            setState(() {});
            syncMessages();
          },
          child: Text(
            "Sync",
            style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary),
          ),
        )
      ];
    } else {
      content = Container(
        height: 5,
        child: Center(
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: context.theme.colorScheme.outline,
            valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
          ),
        ),
      );

      actions = [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            "OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary),
          ),
        )
      ];
    }

    return AlertDialog(
      backgroundColor: context.theme.colorScheme.properSurface,
      title: Text(title, style: context.theme.textTheme.titleLarge),
      content: content,
      actions: actions,
    );
  }
}