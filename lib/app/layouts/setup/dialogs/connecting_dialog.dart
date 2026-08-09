import 'package:bluebubbles/app/layouts/setup/dialogs/failed_to_connect_dialog.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ConnectingDialog extends StatefulWidget {
  const ConnectingDialog({super.key, required this.onConnect});
  final Function(bool) onConnect;

  @override
  State<ConnectingDialog> createState() => _ConnectingDialogState();
}

class _ConnectingDialogState extends State<ConnectingDialog> {
  Worker? _socketStateWorker;

  @override
  void initState() {
    super.initState();

    // Always wait for a fresh connect/error transition rather than trusting
    // the socket state at mount time — it may still reflect a stale
    // connection (e.g. to the previously configured server) since the caller
    // hasn't necessarily kicked off the new connection attempt yet.
    _socketStateWorker = ever(SocketSvc.state, (event) {
      if (!mounted) return;
      if (event == SocketState.connected) {
        widget.onConnect(true);
      } else if (event == SocketState.error) {
        widget.onConnect(false);
      }

      setState(() {});
    });
  }

  @override
  void dispose() {
    _socketStateWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (SocketSvc.state.value == SocketState.error) {
      return FailedToConnectDialog(
        onDismiss: () => Navigator.of(context).pop(),
      );
    } else {
      return PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(
            "Connecting...",
            style: context.theme.textTheme.titleLarge,
          ),
          backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
          content: LinearProgressIndicator(
            backgroundColor: context.theme.colorScheme.outline,
            valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
          ),
        ),
      );
    }
  }
}
