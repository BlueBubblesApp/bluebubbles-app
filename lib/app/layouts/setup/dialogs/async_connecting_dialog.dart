import 'package:bluebubbles/app/layouts/setup/dialogs/failed_to_connect_dialog.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AsyncConnectingDialog extends StatefulWidget {
  AsyncConnectingDialog({Key? key, required this.onConnect, required this.future, this.showErrorDialog = true})
      : super(key: key);
  final Function(bool, Object?) onConnect;
  final Future<dio.Response> future;
  final bool showErrorDialog;

  @override
  State<AsyncConnectingDialog> createState() => _AsyncConnectingDialogState();
}

class _AsyncConnectingDialogState extends OptimizedState<AsyncConnectingDialog> {
  @override
  void initState() {
    super.initState();

    widget.future.then((value) {
      widget.onConnect(true, null);
    }).catchError((e) {
      widget.onConnect(false, e);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: widget.future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            if (widget.showErrorDialog) {
              return FailedToConnectDialog(
                onDismiss: () => Navigator.of(context).pop(),
              );
            } else if (!(snapshot.error is dio.Response && (snapshot.error as dio.Response).statusCode == 404)){
              Navigator.of(context).pop();
              return WillPopScope(
                onWillPop: () async {
                  return false;
                },
                child: Container(),
              );
            }
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return WillPopScope(
              onWillPop: () async {
                return false;
              },
              child: AlertDialog(
                title: Text(
                  "Connecting...",
                  style: context.theme.textTheme.titleLarge,
                ),
                backgroundColor: context.theme.colorScheme.properSurface,
                content: LinearProgressIndicator(
                  backgroundColor: context.theme.colorScheme.outline,
                  valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                ),
              ),
            );
          }

          return WillPopScope(
            onWillPop: () async {
              return false;
            },
            child: AlertDialog(
              title: Text(
                "Success!",
                style: context.theme.textTheme.titleLarge,
              ),
              backgroundColor: context.theme.colorScheme.properSurface,
              content: Text(
                "Connected!",
                style: context.theme.textTheme.bodyLarge,
              ),
            ),
          );
        });
  }
}
