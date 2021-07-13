import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_widget.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RedactedModePanel extends StatefulWidget {
  RedactedModePanel({Key? key}) : super(key: key);

  @override
  _RedactedModePanelState createState() => _RedactedModePanelState();
}

class _RedactedModePanelState extends State<RedactedModePanel> with TickerProviderStateMixin {

  @override
  void initState() {
    super.initState();

    // Listen for any incoming events
    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!event.containsKey("type")) return;

      if (event["type"] == 'theme-update' && this.mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final iosSubtitle = Theme.of(context).textTheme.subtitle1?.copyWith(color: Colors.grey, fontWeight: FontWeight.w300);
    final materialSubtitle = Theme.of(context).textTheme.subtitle1?.copyWith(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold);
    Color headerColor;
    Color tileColor;
    if (Theme.of(context).accentColor.computeLuminance() < Theme.of(context).backgroundColor.computeLuminance()
        || SettingsManager().settings.skin.value != Skins.iOS) {
      headerColor = Theme.of(context).accentColor;
      tileColor = Theme.of(context).backgroundColor;
    } else {
      headerColor = Theme.of(context).backgroundColor;
      tileColor = Theme.of(context).accentColor;
    }
    if (SettingsManager().settings.skin.value == Skins.iOS && isEqual(Theme.of(context), oledDarkTheme)) {
      tileColor = headerColor;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: headerColor, // navigation bar color
        systemNavigationBarIconBrightness:
        headerColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
        backgroundColor: SettingsManager().settings.skin.value != Skins.iOS ? tileColor : headerColor,
        appBar: PreferredSize(
          preferredSize: Size(context.width, 80),
          child: ClipRRect(
            child: BackdropFilter(
              child: AppBar(
                brightness: ThemeData.estimateBrightnessForColor(headerColor),
                toolbarHeight: 100.0,
                elevation: 0,
                leading: buildBackButton(context),
                backgroundColor: headerColor.withOpacity(0.5),
                title: Text(
                  "Redacted Mode Settings",
                  style: Theme.of(context).textTheme.headline1,
                ),
              ),
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            ),
          ),
        ),
        body: CustomScrollView(
          physics: ThemeSwitcher.getScrollPhysics(),
          slivers: <Widget>[
            Obx(() => SliverList(
              delegate: SliverChildListDelegate(
                <Widget>[
                  Container(
                      height: SettingsManager().settings.skin.value == Skins.iOS ? 30 : 40,
                      alignment: Alignment.bottomLeft,
                      decoration: SettingsManager().settings.skin.value == Skins.iOS ? BoxDecoration(
                        color: headerColor,
                        border: Border(
                            bottom: BorderSide(color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)
                        ),
                      ) : BoxDecoration(
                        color: tileColor,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8.0, left: 15),
                        child: Text("Redacted Mode".psCapitalize, style: SettingsManager().settings.skin.value == Skins.iOS ? iosSubtitle : materialSubtitle),
                      )
                  ),
                  Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8.0, left: 15, top: 8.0, right: 15),
                        child: Text(
                            "Redacted Mode hides your personal information, such as contact names, message content, and more. This is useful when taking screenshots to send to developers."
                        ),
                      )
                  ),
                  AbsorbPointer(
                    absorbing: true,
                    child: MessageWidget(
                      newerMessage: null,
                      olderMessage: null,
                      isFirstSentMessage: false,
                      showHandle: true,
                      showHero: false,
                      message: Message(
                          guid: "redacted-mode-demo",
                          dateDelivered: DateTime.now().toLocal(),
                          isFromMe: false,
                          hasReactions: true,
                          text: "This is a preview of Redacted Mode settings.",
                          handle: Handle(
                            id: Random.secure().nextInt(10000),
                            address: "John Doe",
                          ),
                          associatedMessages: [
                            Message(
                              guid: "redacted-mode-demo",
                              text: "Jane Doe liked a message you sent",
                              associatedMessageType: "like",
                              isFromMe: true,
                            ),
                          ]
                      ),
                    ),
                  ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      SettingsManager().settings.redactedMode.value = val;
                      if (this.mounted) {
                        setState(() {
                          SettingsManager().settings.redactedMode.value = val;
                        });
                      }

                      saveSettings();
                    },
                    initialVal: SettingsManager().settings.redactedMode.value,
                    title: "Enable Redacted Mode",
                  ),
                  if (SettingsManager().settings.redactedMode.value)
                    ...[
                      SettingsHeader(
                          headerColor: headerColor,
                          tileColor: tileColor,
                          iosSubtitle: iosSubtitle,
                          materialSubtitle: materialSubtitle,
                          text: "Hide Content"
                      ),
                      SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.hideMessageContent.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.hideMessageContent.value,
                        title: "Hide Message Content",
                        backgroundColor: tileColor,
                        subtitle: "Removes any trace of message text",
                      ),
                      SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.hideReactions.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.hideReactions.value,
                        title: "Hide Reactions",
                        backgroundColor: tileColor,
                        subtitle: "Removes any trace of reactions from messages",
                      ),
                      SettingsHeader(
                          headerColor: headerColor,
                          tileColor: tileColor,
                          iosSubtitle: iosSubtitle,
                          materialSubtitle: materialSubtitle,
                          text: "Hide Emojis & Attachments",
                      ),
                      SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.hideEmojis.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.hideEmojis.value,
                        title: "Hide Big Emojis",
                        backgroundColor: tileColor,
                        subtitle: "Replaces large emojis with placeholder boxes",
                      ),
                      SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.hideAttachments.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.hideAttachments.value,
                        title: "Hide Attachments",
                        backgroundColor: tileColor,
                        subtitle: "Replaces attachments with placeholder boxes",
                      ),
                      SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.hideAttachmentTypes.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.hideAttachmentTypes.value,
                        title: "Hide Attachment Types",
                        backgroundColor: tileColor,
                        subtitle: "Removes the attachment file type text from the placeholder box",
                      ),
                      SettingsHeader(
                        headerColor: headerColor,
                        tileColor: tileColor,
                        iosSubtitle: iosSubtitle,
                        materialSubtitle: materialSubtitle,
                        text: "Hide Contact Info"
                      ),
                      SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.hideContactPhotos.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.hideContactPhotos.value,
                        title: "Hide Contact Photos",
                        backgroundColor: tileColor,
                        subtitle: "Replaces message bubbles with empty bubbles",
                      ),
                      SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.hideContactInfo.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.hideContactInfo.value,
                        title: "Hide Contact Info",
                        backgroundColor: tileColor,
                        subtitle: "Removes any trace of contact names, numbers, and emails",
                      ),
                      SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.removeLetterAvatars.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.removeLetterAvatars.value,
                        title: "Remove Letter Avatars",
                        backgroundColor: tileColor,
                        subtitle: "Replaces letter avatars with generic person avatars",
                      ),
                      SettingsHeader(
                          headerColor: headerColor,
                          tileColor: tileColor,
                          iosSubtitle: iosSubtitle,
                          materialSubtitle: materialSubtitle,
                          text: "Generate Fake Info"
                      ),
                      SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.generateFakeContactNames.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.generateFakeContactNames.value,
                        title: "Generate Fake Contact Names",
                        backgroundColor: tileColor,
                        subtitle: "Replaces contact names, numbers, and emails with auto-generated fake names",
                      ),
                      SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.generateFakeMessageContent.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.generateFakeMessageContent.value,
                        title: "Generate Fake Message Content",
                        backgroundColor: tileColor,
                        subtitle: "Replaces message text with lorem-ipsum text",
                      ),
                    ],
                  Container(color: tileColor, padding: EdgeInsets.only(top: 5.0)),
                  Container(
                    height: 30,
                    decoration: SettingsManager().settings.skin.value == Skins.iOS ? BoxDecoration(
                      color: headerColor,
                      border: Border(
                          top: BorderSide(color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)
                      ),
                    ) : null,
                  ),
                ],
              ),
            )),
            SliverList(
              delegate: SliverChildListDelegate(
                <Widget>[],
              ),
            )
          ],
        ),
      ),
    );
  }

  void saveSettings() {
    SettingsManager().saveSettings(SettingsManager().settings);
  }

  @override
  void dispose() {
    saveSettings();
    super.dispose();
  }
}
