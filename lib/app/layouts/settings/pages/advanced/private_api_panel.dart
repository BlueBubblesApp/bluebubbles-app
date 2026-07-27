import 'package:animated_size_and_fade/animated_size_and_fade.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/reaction_type_picker.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/models/models.dart' show ServerDetails;
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version/version.dart';

class PrivateAPIPanelController extends StatefulController {
  final Rx<ServerDetails> serverDetails = Rx(const ServerDetails.empty());

  @override
  void onReady() {
    super.onReady();
    HttpSvc.server.info().then((response) {
      final String serverVersionStr = response.data['data']['server_version'] ?? "0.0.1";
      Version version = Version.parse(serverVersionStr);
      serverDetails.value = ServerDetails(
        macOSVersion: SettingsSvc.serverDetails.macOSVersion,
        macOSMinorVersion: SettingsSvc.serverDetails.macOSMinorVersion,
        serverVersion: serverVersionStr,
        serverVersionCode: version.major * 100 + version.minor * 21 + version.patch,
      );
    });
  }
}

class PrivateAPIPanel extends CustomStateful<PrivateAPIPanelController> {
  PrivateAPIPanel({super.key, this.enablePrivateAPIonInit = false})
      : super(parentController: Get.put(PrivateAPIPanelController()));

  final bool enablePrivateAPIonInit;

  @override
  State<StatefulWidget> createState() => _PrivateAPIPanelState();
}

class _PrivateAPIPanelState extends CustomState<PrivateAPIPanel, void, PrivateAPIPanelController> {
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      if (widget.enablePrivateAPIonInit && SettingsSvc.settings.serverPrivateAPI.value == true) {
        SettingsSvc.settings.enablePrivateAPI.value = true;
        SettingsSvc.settings.privateAPISend.value = true;
        HttpSvc.server.info().then((response) {
          final String serverVersionStr = response.data['data']['server_version'] ?? "0.0.1";
          Version version = Version.parse(serverVersionStr);
          controller.serverDetails.value = ServerDetails(
            macOSVersion: SettingsSvc.serverDetails.macOSVersion,
            macOSMinorVersion: SettingsSvc.serverDetails.macOSMinorVersion,
            serverVersion: serverVersionStr,
            serverVersionCode: version.major * 100 + version.minor * 21 + version.patch,
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(expressive: true, 
        title: "Private API Features",
        initialHeader: "Private API",
        iosSubtitle: iosSubtitle,
        materialSubtitle: materialSubtitle,
        tileColor: tileColor,
        headerColor: headerColor,
        bodySlivers: [
          SliverList(
            delegate: SliverChildListDelegate(
              <Widget>[
                Obx(
                  () => SettingsSection(expressive: true, 
                    backgroundColor: tileColor,
                    children: [
                      if (!SettingsSvc.settings.enablePrivateAPI.value ||
                          SettingsSvc.settings.serverPrivateAPI.value != true)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0, left: 15, top: 8.0, right: 15),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(text: "Private API features give you the ability to:\n"),
                                const TextSpan(text: " - Send tapbacks, effects, and mentions\n"),
                                const TextSpan(text: " - Send messages with subject lines\n"),
                                if (SettingsSvc.serverDetails.isMinBigSur) const TextSpan(text: " - Send replies\n"),
                                if (SettingsSvc.serverDetails.isMinVentura)
                                  const TextSpan(text: " - Edit & Unsend messages\n"),
                                if (SettingsSvc.serverDetails.isMinBigSur)
                                  const TextSpan(text: " - Receive Digital Touch messages\n"),
                                const TextSpan(text: "\n"),
                                const TextSpan(text: " - Mark chats read on the Mac server\n"),
                                if (SettingsSvc.serverDetails.isMinVentura)
                                  const TextSpan(text: " - Mark chats as unread on the Mac server\n"),
                                const TextSpan(text: "\n"),
                                const TextSpan(text: " - Rename group chats\n"),
                                const TextSpan(text: " - Add & remove people from group chats\n"),
                                if (SettingsSvc.serverDetails.isMinBigSur)
                                  const TextSpan(text: " - Change the group chat photo\n"),
                                const TextSpan(text: "\n"),
                                const TextSpan(text: " - Know if a recipient is registered with iMessage\n"),
                                if (SettingsSvc.serverDetails.isMinMonterey)
                                  const TextSpan(text: " - View Focus statuses\n"),
                                if (SettingsSvc.serverDetails.isMinBigSur)
                                  const TextSpan(text: " - Use Find My Friends\n"),
                                if (SettingsSvc.serverDetails.isMinBigSur)
                                  const TextSpan(text: " - Be notified of incoming FaceTime calls\n"),
                                if (SettingsSvc.serverDetails.isMinVentura)
                                  const TextSpan(text: " - Answer FaceTime calls (experimental)\n"),
                                const TextSpan(text: "\n"),
                                const TextSpan(
                                    text:
                                        "You must have the Private API bundle installed on the server for these features to function, regardless of whether you enable the setting here."),
                              ],
                              style: context.theme.textTheme.bodyMedium,
                            ),
                          ),
                        ),
                      if (SettingsSvc.settings.serverPrivateAPI.value != true)
                        SettingsTile(
                          backgroundColor: tileColor,
                          title: "Set up Private API Features",
                          subtitle: "View instructions on how to set up these features",
                          onTap: () async {
                            await launchUrl(
                                Uri(scheme: "https", host: "docs.bluebubbles.app", path: "helper-bundle/installation"),
                                mode: LaunchMode.externalApplication);
                          },
                          leading: const SettingsLeadingIcon(
                            expressive: true,
                            iosIcon: CupertinoIcons.checkmark_shield,
                            materialIcon: Icons.privacy_tip,
                            containerColor: Colors.blue,
                          ),
                        ),
                      if (SettingsSvc.settings.serverPrivateAPI.value != true) const SettingsDivider(),
                      Obx(
                        () => SettingsSwitch(
                          onChanged: (bool val) async {
                            SettingsSvc.settings.enablePrivateAPI.value = val;
                            await SettingsSvc.settings.saveOneAsync('enablePrivateAPI');
                          },
                          initialVal: SettingsSvc.settings.enablePrivateAPI.value,
                          title: "Enable Private API Features",
                          subtitle: SettingsSvc.settings.serverPrivateAPI.value != null
                              ? "Private API features are ${SettingsSvc.settings.serverPrivateAPI.value! ? "set up" : "not set up"} on the server${!SettingsSvc.settings.serverPrivateAPI.value! ? "!" : ""}"
                              : null,
                          backgroundColor: tileColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Obx(
                  () => AnimatedSizeAndFade.showHide(
                    show: SettingsSvc.settings.enablePrivateAPI.value,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SettingsHeader(
                          iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Private API Settings"),
                      SettingsSection(expressive: true, 
                        backgroundColor: tileColor,
                        children: [
                          SettingsSwitch(
                            onChanged: (bool val) async {
                              SettingsSvc.settings.privateSendTypingIndicators.value = val;
                              await SettingsSvc.settings.saveOneAsync('privateSendTypingIndicators');
                            },
                            initialVal: SettingsSvc.settings.privateSendTypingIndicators.value,
                            title: "Send Typing Indicators",
                            subtitle: "Sends typing indicators to other iMessage users",
                            backgroundColor: tileColor,
                            leading: const SettingsLeadingIcon(
                              expressive: true,
                              iosIcon: CupertinoIcons.keyboard_chevron_compact_down,
                              materialIcon: Icons.keyboard_alt_outlined,
                              containerColor: Colors.green,
                            ),
                          ),
                          AnimatedSizeAndFade(
                            child: !SettingsSvc.settings.privateManualMarkAsRead.value
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SettingsDivider(),
                                      SettingsSwitch(
                                          onChanged: (bool val) async {
                                            SettingsSvc.settings.privateMarkChatAsRead.value = val;
                                            final toSave = ['privateMarkChatAsRead'];
                                            if (val) {
                                              SettingsSvc.settings.privateManualMarkAsRead.value = false;
                                              toSave.add('privateManualMarkAsRead');
                                            }

                                            await SettingsSvc.settings.saveManyAsync(toSave);
                                          },
                                          initialVal: SettingsSvc.settings.privateMarkChatAsRead.value,
                                          title: "Automatic Mark Read / Send Read Receipts",
                                          subtitle:
                                              "Marks chats read in the iMessage app on your server and sends read receipts to other iMessage users",
                                          backgroundColor: tileColor,
                                          isThreeLine: true,
                                          leading: const SettingsLeadingIcon(
                                            expressive: true,
                                            iosIcon: CupertinoIcons.rectangle_fill_badge_checkmark,
                                            materialIcon: Icons.playlist_add_check,
                                            containerColor: Colors.blueAccent,
                                          )),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                          AnimatedSizeAndFade.showHide(
                            show: !SettingsSvc.settings.privateMarkChatAsRead.value,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SettingsDivider(),
                                SettingsSwitch(
                                  onChanged: (bool val) async {
                                    SettingsSvc.settings.privateManualMarkAsRead.value = val;
                                    await SettingsSvc.settings.saveOneAsync('privateManualMarkAsRead');
                                  },
                                  initialVal: SettingsSvc.settings.privateManualMarkAsRead.value,
                                  title: "Manual Mark Read / Send Read Receipts",
                                  subtitle: "Only mark a chat read when pressing the manual mark read button",
                                  backgroundColor: tileColor,
                                  isThreeLine: true,
                                  leading: const SettingsLeadingIcon(
                                    expressive: true,
                                    iosIcon: CupertinoIcons.check_mark_circled,
                                    materialIcon: Icons.check_circle_outline,
                                    containerColor: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SettingsDivider(),
                          SettingsSwitch(
                            title: "Double-${kIsWeb || kIsDesktop ? "Click" : "Tap"} Message for Quick Tapback",
                            initialVal: SettingsSvc.settings.enableQuickTapback.value,
                            onChanged: (bool val) async {
                              SettingsSvc.settings.enableQuickTapback.value = val;
                              final toSave = ['enableQuickTapback'];
                              if (val && SettingsSvc.settings.doubleTapForDetails.value) {
                                SettingsSvc.settings.doubleTapForDetails.value = false;
                                toSave.add('doubleTapForDetails');
                              }

                              await SettingsSvc.settings.saveManyAsync(toSave);
                            },
                            subtitle:
                                "Send a tapback of your choosing when double ${kIsWeb || kIsDesktop ? "click" : "tapp"}ing a message",
                            backgroundColor: tileColor,
                            isThreeLine: true,
                            leading: const SettingsLeadingIcon(
                              expressive: true,
                              iosIcon: CupertinoIcons.rays,
                              materialIcon: Icons.touch_app_outlined,
                              containerColor: Colors.purple,
                            ),
                          ),
                          AnimatedSizeAndFade.showHide(
                            show: SettingsSvc.settings.enableQuickTapback.value,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 5.0),
                              child: Obx(() => ReactionTypePicker(
                                    title: "Quick Tapback",
                                    currentValue: SettingsSvc.settings.quickTapbackType.value,
                                    reactions: ReactionTypes.toList(),
                                    onChanged: (val) async {
                                      if (val == null) return;
                                      SettingsSvc.settings.quickTapbackType.value = val;
                                      await SettingsSvc.settings.saveOneAsync('quickTapbackType');
                                    },
                                    secondaryColor: headerColor,
                                    useModernMenu: true,
                                  )),
                            ),
                          ),
                          AnimatedSizeAndFade.showHide(
                            show: SettingsSvc.serverDetails.isMinVentura &&
                                SettingsSvc.serverDetails.supportsEditAndUnsend,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SettingsDivider(),
                                SettingsSwitch(
                                  title: "Up Arrow for Quick Edit",
                                  initialVal: SettingsSvc.settings.editLastSentMessageOnUpArrow.value,
                                  onChanged: (bool val) async {
                                    SettingsSvc.settings.editLastSentMessageOnUpArrow.value = val;
                                    await SettingsSvc.settings.saveOneAsync('editLastSentMessageOnUpArrow');
                                  },
                                  subtitle: "Press the Up Arrow to begin editing the last message you sent",
                                  backgroundColor: tileColor,
                                  leading: const SettingsLeadingIcon(
                                    expressive: true,
                                    iosIcon: CupertinoIcons.arrow_up_square,
                                    materialIcon: Icons.arrow_circle_up,
                                    containerColor: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedSizeAndFade.showHide(
                            show: controller.serverDetails.value.supportsSubjectLines,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SettingsDivider(),
                                SettingsSwitch(
                                  onChanged: (bool val) async {
                                    SettingsSvc.settings.privateSubjectLine.value = val;
                                    await SettingsSvc.settings.saveOneAsync('privateSubjectLine');
                                  },
                                  initialVal: SettingsSvc.settings.privateSubjectLine.value,
                                  title: "Send Subject Lines",
                                  subtitle: "Show the subject line field when sending a message",
                                  backgroundColor: tileColor,
                                  isThreeLine: true,
                                  leading: const SettingsLeadingIcon(
                                    expressive: true,
                                    iosIcon: CupertinoIcons.textformat,
                                    materialIcon: Icons.text_format_rounded,
                                    containerColor: Colors.blueAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedSizeAndFade.showHide(
                            show: controller.serverDetails.value.supportsPrivateApiSend,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SettingsDivider(),
                                SettingsSwitch(
                                  onChanged: (bool val) async {
                                    SettingsSvc.settings.privateAPISend.value = val;
                                    await SettingsSvc.settings.saveOneAsync('privateAPISend');
                                  },
                                  initialVal: SettingsSvc.settings.privateAPISend.value,
                                  title: "Private API Send",
                                  subtitle: "Send regular iMessages using the Private API for much faster speed",
                                  backgroundColor: tileColor,
                                  isThreeLine: true,
                                  leading: const SettingsLeadingIcon(
                                    expressive: true,
                                    iosIcon: CupertinoIcons.bubble_right,
                                    materialIcon: Icons.chat_bubble_outline,
                                    containerColor: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedSizeAndFade.showHide(
                            show: controller.serverDetails.value.supportsPrivateApiAttachmentSend,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SettingsDivider(),
                                SettingsSwitch(
                                  onChanged: (bool val) async {
                                    SettingsSvc.settings.privateAPIAttachmentSend.value = val;
                                    await SettingsSvc.settings.saveOneAsync('privateAPIAttachmentSend');
                                  },
                                  initialVal: SettingsSvc.settings.privateAPIAttachmentSend.value,
                                  title: "Private API Attachment Send",
                                  subtitle: "Send attachments using the Private API",
                                  backgroundColor: tileColor,
                                  isThreeLine: true,
                                  leading: const SettingsLeadingIcon(
                                    expressive: true,
                                    iosIcon: CupertinoIcons.paperclip,
                                    materialIcon: Icons.attach_file_outlined,
                                    containerColor: Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ]);
  }
}
