import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/app/layouts/setup/dialogs/failed_to_connect_dialog.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ConnectingDialog extends StatefulWidget {
  ConnectingDialog({Key? key, required this.onConnect}) : super(key: key);
  final Function(bool) onConnect;

  @override
  State<ConnectingDialog> createState() => _ConnectingDialogState();
}

class _ConnectingDialogState extends OptimizedState<ConnectingDialog> {

  @override
  void initState() {
    super.initState();

    if (socket.state.value == SocketState.connected) {
      widget.onConnect(true);
    } else {
      // Set up a listener to wait for connect events
      ever(socket.state, (event) {
        if (event == SocketState.connected) {
          widget.onConnect(true);
        } else if (event == SocketState.error || event == SocketState.disconnected) {
          widget.onConnect(false);
        }
        setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (socket.state.value == SocketState.error) {
      return FailedToConnectDialog(
        onDismiss: () => Navigator.of(context).pop(),
      );
    } else {
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
  }
}
