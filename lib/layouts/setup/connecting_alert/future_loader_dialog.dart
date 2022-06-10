import 'package:bluebubbles/layouts/setup/connecting_alert/failed_to_connect_dialog.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FutureLoaderDialog extends StatefulWidget {
  FutureLoaderDialog({Key? key, required this.onConnect, required this.future, this.showErrorDialog = true})
      : super(key: key);
  final Function(bool, Object?) onConnect;
  final Future<dio.Response> future;
  final bool showErrorDialog;

  @override
  State<FutureLoaderDialog> createState() => _FutureLoaderDialogState();
}

class _FutureLoaderDialogState extends State<FutureLoaderDialog> {
  @override
  void initState() {
    super.initState();

    widget.future.then((value) {
      widget.onConnect(true, null);
    }).catchError((e) {
      widget.onConnect(false, e.toString());
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
            } else {
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
                backgroundColor: context.theme.colorScheme.surface,
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
              backgroundColor: context.theme.colorScheme.surface,
              content: Text(
                "Connected!",
                style: context.theme.textTheme.bodyLarge,
              ),
            ),
          );
        });
  }
}
