import 'dart:convert';

import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/avatar/avatar_crop.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:universal_io/io.dart';

class ProfilePanel extends StatefulWidget {

  ProfilePanel({super.key});

  @override
  State<ProfilePanel> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends OptimizedState<ProfilePanel> with WidgetsBindingObserver {
  final RxDouble opacity = 1.0.obs;
  final RxMap<String, dynamic> accountInfo = RxMap({});
  final RxMap<String, dynamic> accountContact = RxMap({});

  @override
  void initState() {
    super.initState();
    getDetails();
  }

  void getDetails() async {
    try {
      final result = await http.getAccountInfo();
      if (!isNullOrEmpty(result.data.isNotEmpty)!) {
        accountInfo.addAll(result.data['data']);
      }
      opacity.value = 1.0;
      if (ss.isMinBigSurSync) {
        final result2 = await http.getAccountContact();
        if (!isNullOrEmpty(result2.data.isNotEmpty)!) {
          accountContact.addAll(result2.data['data']);
        }
      }
    } catch (_) {

    }
    setState(() {});
  }

  void updateName() async {
    final nameController = TextEditingController(text: ss.settings.userName.value);
    done() {
      if (nameController.text.isEmpty) {
        showSnackbar("Error", "Enter a name!");
        return;
      }
      Get.back();
      ss.settings.userName.value = nameController.text;
      ss.settings.save();
      setState(() {});
    }
    await showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            actions: [
              TextButton(
                child: Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                onPressed: () => Get.back(),
              ),
              TextButton(
                child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                onPressed: () async {
                  done.call();
                },
              ),
            ],
            content: TextField(
              controller: nameController,
              onSubmitted: (_) => done.call(),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: "Name",
                border: OutlineInputBorder(),
              ),
            ),
            title: Text("User Profile Name", style: context.theme.textTheme.titleLarge),
            backgroundColor: context.theme.colorScheme.properSurface,
          );
        }
    );
  }

  void updatePhoto() async {
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (context) => AvatarCrop(),
      ),
    );
  }

  void removePhoto() {
    File file = File(ss.settings.userAvatarPath.value!);
    file.delete();
    ss.settings.userAvatarPath.value = null;
    ss.saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      headerColor: headerColor,
      title: "iMessage Profile",
      tileColor: tileColor,
      initialHeader: null,
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      bodySlivers: [
        SliverToBoxAdapter(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                if (iOS)
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            updatePhoto();
                          },
                          child: ContactAvatarWidget(
                            handle: null,
                            borderThickness: 0.1,
                            editable: false,
                            fontSize: 22,
                            size: 100,
                          ),
                        ),
                        Obx(() => ss.settings.userAvatarPath.value != null ? Positioned(
                          right: -5,
                          top: -5,
                          child: InkWell(
                            onTap: () async {
                              removePhoto();
                            },
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                border: Border.all(color: context.theme.colorScheme.background, width: 1),
                                shape: BoxShape.circle,
                                color: context.theme.colorScheme.tertiaryContainer,
                              ),
                              child: Icon(
                                Icons.close,
                                color: context.theme.colorScheme.onTertiaryContainer,
                                size: 20,
                              ),
                            ),
                          ),
                        ) : const SizedBox.shrink()),
                      ],
                    ),
                  ),
                if (iOS)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Center(
                      child: RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: context.theme.textTheme.headlineMedium!.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.theme.colorScheme.onBackground,
                          ),
                          children: MessageHelper.buildEmojiText(
                            ss.settings.redactedMode.value && ss.settings.hideContactInfo.value
                                ? "User Name" : ss.settings.userName.value,
                            context.theme.textTheme.headlineMedium!.copyWith(
                              fontWeight: FontWeight.bold,
                              color: context.theme.colorScheme.onBackground,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (iOS)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Center(
                      child: RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: context.theme.textTheme.bodyMedium!.apply(color: context.theme.colorScheme.outline),
                          children: MessageHelper.buildEmojiText(
                              ss.settings.redactedMode.value && ss.settings.hideContactInfo.value
                                  ? "User iCloud"
                                  : ss.settings.iCloudAccount.isEmpty
                                  ? "Unknown iCloud account"
                                  : ss.settings.iCloudAccount.value,
                              context.theme.textTheme.bodyMedium!.apply(color: context.theme.colorScheme.outline)
                          ),
                        ),
                      ),
                    ),
                  ),
                if (iOS)
                  Center(
                    child: TextButton(
                      child: Text(
                        "Change Name",
                        style: context.theme.textTheme.bodyMedium!.apply(color: context.theme.colorScheme.primary),
                        textScaler: const TextScaler.linear(1.15),
                      ),
                      onPressed: () async {
                        updateName();
                      },
                    ),
                  ),
                if (!iOS)
                  Padding(
                    padding: const EdgeInsets.only(left: 15.0, bottom: 5.0),
                    child: Text(
                        "YOUR NAME AND PHOTO",
                        style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline)
                    ),
                  ),
                if (!iOS)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5.0),
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        mouseCursor: MouseCursor.defer,
                        leading: ContactAvatarWidget(
                          handle: null,
                          borderThickness: 0.1,
                          editable: false,
                          fontSize: 22,
                          size: 50,
                        ),
                        onTap: () async {
                          updateName();
                        },
                        title: RichText(
                          text: TextSpan(
                            style: context.theme.textTheme.bodyLarge,
                            children: MessageHelper.buildEmojiText(
                              ss.settings.redactedMode.value && ss.settings.hideContactInfo.value
                                  ? "User Name" : ss.settings.userName.value,
                              context.theme.textTheme.bodyLarge!,
                            ),
                          ),
                        ),
                        subtitle: Text(ss.settings.redactedMode.value && ss.settings.hideContactInfo.value
                            ? "User iCloud"
                            : ss.settings.iCloudAccount.isEmpty
                            ? "Unknown iCloud account"
                            : ss.settings.iCloudAccount.value, style: context.theme.textTheme.bodyMedium!.apply(color: context.theme.colorScheme.outline)),
                        trailing: Icon(Icons.edit_outlined, color: context.theme.colorScheme.onBackground),
                      ),
                    ),
                  ),
                if (!iOS)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5.0),
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        mouseCursor: MouseCursor.defer,
                        onTap: () async {
                          updatePhoto();
                        },
                        title: Text("Update your photo", style: context.theme.textTheme.bodyLarge!),
                        trailing: Icon(Icons.edit_outlined, color: context.theme.colorScheme.onBackground),
                      ),
                    ),
                  ),
                if (!iOS)
                  Obx(() => ss.settings.userAvatarPath.value != null ? Padding(
                    padding: const EdgeInsets.only(bottom: 5.0),
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        mouseCursor: MouseCursor.defer,
                        onTap: () async {
                          removePhoto();
                        },
                        title: Text("Remove your photo", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.error)),
                        trailing: Icon(Icons.close, color: context.theme.colorScheme.error),
                      ),
                    ),
                  ) : const SizedBox.shrink()),
                SettingsHeader(
                    iosSubtitle: iosSubtitle,
                    materialSubtitle: materialSubtitle,
                    text: "iCloud Account Info"),
                Skeletonizer(
                  enabled: accountInfo.isEmpty,
                  child: SettingsSection(
                    backgroundColor: tileColor,
                    children: [
                      Obx(() {
                        bool redact = ss.settings.redactedMode.value;
                        return Container(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8.0, left: 15, top: 8.0, right: 15),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: opacity.value,
                              child: SelectableText.rich(
                                TextSpan(children: [
                                  TextSpan(text: redact ? "Account Name - Apple ID" : "${accountInfo['account_name']} - ${accountInfo['apple_id']}"),
                                  const TextSpan(text: "\n"),
                                  const TextSpan(text: "iMessage Status: ", style: TextStyle(height: 3.0)),
                                  TextSpan(
                                      text: accountInfo['login_status_message']?.toUpperCase(),
                                      style: TextStyle(color: getIndicatorColor(accountInfo['login_status_message'] == "Connected" ? SocketState.connected : SocketState.disconnected))),
                                  const TextSpan(text: "\n"),
                                  const TextSpan(text: "SMS Forwarding Status: "),
                                  TextSpan(
                                      text: accountInfo['sms_forwarding_enabled'] == true ? "ENABLED" : "DISABLED",
                                      style: TextStyle(color: getIndicatorColor(accountInfo['sms_forwarding_enabled'] == true ? SocketState.connected : SocketState.disconnected))),
                                  const TextSpan(text: "  |  "),
                                  TextSpan(
                                      text: accountInfo['sms_forwarding_capable'] == true ? "CAPABLE" : "INCAPABLE",
                                      style: TextStyle(color: getIndicatorColor(accountInfo['sms_forwarding_capable'] == true ? SocketState.connected : SocketState.disconnected))),
                                  const TextSpan(text: "\n"),
                                  const TextSpan(text: "VETTED ALIASES\n", style: TextStyle(fontWeight: FontWeight.w700, height: 3.0)),
                                  ...((accountInfo['vetted_aliases'] as List<dynamic>? ?? [])).map((e) => [
                                    TextSpan(text: "⬤  ", style: TextStyle(color: getIndicatorColor(e['Status'] == 3 ? SocketState.connected : SocketState.disconnected))),
                                    TextSpan(text: redact ? "Alias" : "${e['Alias']}\n")
                                  ]).toList().flattened,
                                  const TextSpan(text: "\n"),
                                  const TextSpan(text: "Tap to update values...", style: TextStyle(fontStyle: FontStyle.italic)),
                                ]),
                                onTap: () {
                                  opacity.value = 0.0;
                                  getDetails();
                                },
                              ),
                            ),
                          ));
                      }),
                      if (accountInfo['active_alias'] != null)
                        Container(
                          color: tileColor,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 15.0),
                            child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                          ),
                        ),
                      if (accountInfo['active_alias'] != null)
                        SettingsOptions<String>(
                          title: "Start Chats Using",
                          initial: accountInfo['active_alias'],
                          clampWidth: false,
                          options: accountInfo['vetted_aliases'].map((e) => e['Alias'].toString()).toList().cast<String>(),
                          secondaryColor: headerColor,
                          useCupertino: false,
                          textProcessing: (str) => str,
                          capitalize: false,
                          onChanged: (value) async {
                            if (value == null) return;
                            accountInfo['active_alias'] = value;
                            setState(() {});
                            await http.setAccountAlias(value);
                          },
                        ),
                    ],
                  )),
                if (!isNullOrEmpty(accountContact['name'])!)
                  SettingsHeader(
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "iMessage Contact Card"),
                if (!isNullOrEmpty(accountContact['name'])!)
                  SettingsSection(
                    backgroundColor: tileColor,
                    children: [
                      SettingsTile(
                        leading: (accountContact['avatar'] == null) ? const CircleAvatar() : ContactAvatarWidget(
                          handle: null,
                          contact: isNullOrEmpty(accountContact['avatar'])! ? null : Contact(id: randomString(9), displayName: "", avatar: base64Decode(accountContact['avatar'])),
                        ),
                        title: accountContact['name'],
                        subtitle: "Your sharable iMessage contact card",
                      ),
                      const SettingsSubtitle(subtitle: "Visit iMessage settings on your Mac to update.")
                    ],
                  ),
              ],
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.only(top: 50),
        ),
      ],
    );
  }
}
