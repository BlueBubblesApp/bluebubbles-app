import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/facetime.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Whether the details page offers to FaceTime this chat through the server's Mac: a 1:1 iMessage chat, on a v2
/// server, with the Private API on. Groups aren't offered: the server dials every address as one 1:1 request.
bool canFaceTime(Chat chat) =>
    SettingsSvc.getServerDetails().supportsFaceTimeCalls &&
    SettingsSvc.settings.enablePrivateAPI.value &&
    !chat.isGroup &&
    chat.isIMessage &&
    chat.handles.isNotEmpty &&
    !(chat.chatIdentifier?.startsWith("urn:biz") ?? false);

/// Asks video or audio, has the server's Mac ring the chat's handle, then opens the link to join the call.
Future<void> startFaceTimeCall(BuildContext context, Chat chat) async {
  final video = await showBBListSelector<bool>(
    context: context,
    title: "FaceTime",
    options: const [
      BBListSelectorOption(label: "Video", value: true),
      BBListSelectorOption(label: "Audio", value: false),
    ],
  );
  if (video == null || !context.mounted) return;

  // The root navigator, not this page's context: the page may close while the Mac dials, and the progress dialog
  // and whatever follows it still need somewhere to go.
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const PopScope(canPop: false, child: BBProgressDialog(title: "Calling…")),
  );

  PlacedFaceTimeCall? placed;
  FaceTimeException? refusal;
  try {
    placed = await HttpSvc.faceTime.call(chat.handles.first.address, video: video);
  } on FaceTimeException catch (e) {
    refusal = e;
  } catch (e, s) {
    Logger.warn("Failed to start FaceTime call", error: e, trace: s, tag: 'FaceTime');
    refusal = const FaceTimeException("Couldn't reach the server.");
  } finally {
    navigator.pop();
  }

  if (placed != null) {
    final opened = await launchUrl(Uri.parse(placed.link), mode: LaunchMode.externalApplication);
    if (!opened) showSnackbar("FaceTime", "Couldn't open the call link", type: SnackbarType.error);
    return;
  }

  final ringing = refusal!.call;
  if (ringing == null) {
    if (!navigator.mounted) return;
    showBBDialog(
      context: navigator.context,
      title: "Couldn't Start FaceTime",
      body: refusal.message,
      actions: [BBDialogAction(text: "OK", onPressed: () => navigator.pop())],
    );
    return;
  }

  // Ringing with no way in: the only useful thing left is to stop it.
  if (!navigator.mounted) return;
  showBBDialog(
    context: navigator.context,
    title: "No Link to Join",
    body: "The call is ringing, but the server couldn't make a link to join it.",
    actions: [
      BBDialogAction(text: "Leave Ringing", onPressed: () => navigator.pop()),
      BBDialogAction(
        text: "Hang Up",
        isDestructive: true,
        isDefault: true,
        onPressed: () async {
          navigator.pop();
          try {
            await HttpSvc.faceTime.leave(ringing.callUuid);
          } catch (e, s) {
            Logger.warn("Failed to hang up FaceTime call", error: e, trace: s, tag: 'FaceTime');
            showSnackbar("FaceTime", "Couldn't hang up the call", type: SnackbarType.error);
          }
        },
      ),
    ],
  );
}
