import 'dart:io' show Platform;

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

/// Launch an outgoing call. Cross-platform behavior:
///
/// - macOS/iOS: `facetime:` / `facetime-audio:` opens native FaceTime.
/// - Android/Linux/Windows (video): hit the BB server's `/facetime/session`
///   endpoint to create a real FaceTime Link via the Mac, then offer to
///   copy or send it in the current chat. Replaces the dead Google Duo
///   path — Google killed Duo in 2022 and merged it into Meet.
/// - Android (audio): `tel:` for the native dialer.
void launchIntent(bool video, String address, {BuildContext? context, Chat? chat}) async {
  final bool isApple = !kIsWeb && (Platform.isMacOS || Platform.isIOS);
  final bool isAndroid = !kIsWeb && Platform.isAndroid;

  if (address.contains("@") && !video) {
    await launchUrl(Uri(scheme: "mailto", path: address));
    return;
  }

  if (video) {
    if (isApple) {
      final ok = await launchUrl(Uri(scheme: "facetime", path: address));
      if (!ok) showSnackbar("Error", "Couldn't launch FaceTime for $address");
      return;
    }
    if (context != null && context.mounted) {
      showFaceTimeLinkSheet(context, chat: chat);
      return;
    }
    showSnackbar(
      "FaceTime unavailable",
      "Tap Video Call from a chat to get the FaceTime Link option.",
    );
    return;
  }

  // Audio call path.
  if (isApple) {
    await launchUrl(Uri(scheme: "facetime-audio", path: address));
    return;
  }
  if (isAndroid) {
    if (await Permission.phone.request().isGranted) {
      await launchUrl(Uri(scheme: "tel", path: address));
    }
    return;
  }
  showSnackbar(
    "Calls unavailable",
    "Outgoing calls require an Apple device or an Android phone.",
  );
}

/// Modal sheet that creates a fresh FaceTime Link via the BB server and lets
/// the user copy it or send it directly into [chat]. Apple's web FaceTime
/// works for anyone (Apple or not) — they tap the link, sign in to FaceTime,
/// join from the browser. The link creator (you) joins from your own browser.
void showFaceTimeLinkSheet(BuildContext context, {Chat? chat}) {
  String? link;
  Object? error;
  bool loading = true;

  Future<void> sendInChat() async {
    if (chat == null || link == null) return;
    try {
      final message = Message(
        text: link!,
        dateCreated: DateTime.now(),
        hasAttachments: false,
        isFromMe: true,
        handleId: 0,
      );
      message.generateTempGuid();
      await OutgoingMsgHandler.sendMessage(chat, message, null, null);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      showSnackbar('Sent', 'FaceTime link sent to ${chat.getTitle()}');
    } catch (e) {
      showSnackbar('Send failed', e.toString());
    }
  }

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          if (loading && link == null && error == null) {
            // Fire-and-forget once on first build.
            HttpSvc.faceTime.createSession().then((resp) {
              link = resp.data?["data"]?["link"] as String?;
              error = link == null ? (resp.data?["error"]?["message"] ?? 'No link in response') : null;
              loading = false;
              if (sheetCtx.mounted) setSheetState(() {});
            }).catchError((e) {
              error = e;
              loading = false;
              if (sheetCtx.mounted) setSheetState(() {});
            });
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FaceTime Link', style: sheetCtx.theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (error != null)
                    Text(
                      "Couldn't create a FaceTime link.\n"
                      "Requires BB Server with macOS Monterey+ and Private API enabled.\n\n$error",
                      style: sheetCtx.theme.textTheme.bodyMedium?.copyWith(
                        color: sheetCtx.theme.colorScheme.error,
                      ),
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: sheetCtx.theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        link!,
                        style: sheetCtx.theme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy'),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: link!));
                            showSnackbar('Copied', 'FaceTime link copied');
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Join in browser'),
                          onPressed: () => launchUrl(Uri.parse(link!), mode: LaunchMode.externalApplication),
                        ),
                      ),
                    ]),
                    if (chat != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.send),
                          label: Text('Send to ${chat.getTitle()}'),
                          onPressed: sendInChat,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

void showAddressPicker(ContactV2? contact, Handle handle, BuildContext context,
    {bool isEmail = false, bool video = false, bool isLongPressed = false, Chat? chat}) async {
  if (contact == null) {
    launchIntent(video, handle.address, context: context, chat: chat);
  } else {
    List<String> items = isEmail
        ? getUniqueEmails(contact.emailAddresses.map((e) => e.address))
        : getUniqueNumbers(contact.phoneNumbers.map((p) => p.number));
    if (items.length == 1) {
      launchIntent(video, items.first, context: context, chat: chat);
    } else if (!isEmail && handle.defaultPhone != null && !isLongPressed) {
      launchIntent(video, handle.defaultPhone!, context: context, chat: chat);
    } else if (isEmail && handle.defaultEmail != null && !isLongPressed) {
      launchIntent(video, handle.defaultEmail!, context: context, chat: chat);
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
              backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
              title: Text("Select Address", style: context.theme.textTheme.titleLarge),
              content: ObxValue<Rx<bool>>(
                (data) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < items.length; i++)
                      TextButton(
                        child: Text(
                          items[i],
                          style: context.theme.textTheme.bodyLarge,
                          textAlign: TextAlign.start,
                        ),
                        onPressed: () {
                          if (data.value) {
                            if (isEmail) {
                              handle.defaultEmail = items[i];
                              handle.updateDefaultEmail(items[i]);
                            } else {
                              handle.defaultPhone = items[i];
                              handle.updateDefaultPhone(items[i]);
                            }
                          }
                          launchIntent(video, items[i], context: context, chat: chat);
                          Navigator.of(context).pop();
                        },
                      ),
                    Row(
                      children: <Widget>[
                        SizedBox(
                          height: 48.0,
                          width: 24.0,
                          child: Checkbox(
                            value: data.value,
                            activeColor: context.theme.colorScheme.primary,
                            onChanged: (bool? value) {
                              data.value = value!;
                            },
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              padding: const EdgeInsets.only(left: 5),
                              elevation: 0.0),
                          onPressed: () {
                            data = data.toggle();
                          },
                          child: Text(
                            "Remember my selection",
                            style: context.theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "Long press the ${isEmail ? "email" : "call"} button to reset your default selection",
                      style: context.theme.textTheme.bodySmall!
                          .copyWith(color: context.theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                false.obs,
              ));
        },
      );
    }
  }
}
