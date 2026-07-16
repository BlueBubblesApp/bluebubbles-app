import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/state/chat_state_scope.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

/// Displays a group of contact avatars for a chat.
///
/// **Reactive path** (preferred): when a [ChatStateScope] is present in the
/// widget tree, the widget reads [ChatState.participants] and
/// [ChatState.customAvatarPath] reactively through [Obx]. Participant and
/// avatar changes automatically rebuild the widget without any manual
/// subscriptions.
///
/// **Static path** (fallback): when no [ChatStateScope] is found, the optional
/// [chat] parameter is used instead. The participant list is read once from
/// [Chat.handles] and is non-reactive — no listeners are created.
class ContactAvatarGroupWidget extends StatelessWidget {
  const ContactAvatarGroupWidget({
    super.key,
    this.chat,
    this.size = 40,
    this.editable = true,
  });

  /// Optional chat for scope-less contexts (search, tiles, scheduling panels).
  /// Ignored when a [ChatStateScope] is present above this widget in the tree.
  final Chat? chat;
  final double size;
  final bool editable;

  static final _materialGeneration = <int, List<dynamic>>{
    2: [
      24.5 / 40,
      10.5 / 40,
      <Alignment>[Alignment.topRight, Alignment.bottomLeft]
    ],
    3: [
      21.5 / 40,
      9 / 40,
      <Alignment>[Alignment.bottomRight, Alignment.bottomLeft, Alignment.topCenter]
    ],
    4: [
      1 / 2,
      8.7 / 40,
      <Alignment>[Alignment.bottomRight, Alignment.bottomLeft, Alignment.topLeft, Alignment.topRight]
    ],
  };

  List<Handle> _sortedHandles(List<Handle> handles) {
    final sorted = List<Handle>.from(handles);
    // Sort by the reactive HandleState avatar path — reading contactsV2 here
    // would run a lazy ToMany DB query per handle on every rebuild, and the
    // registry value is also what the child ContactAvatarWidgets display.
    final hasAvatar = {
      for (final h in handles) h: HandleSvc.getOrCreateHandleState(h).avatarPath.value != null,
    };
    sorted.sort((a, b) {
      final avatarA = hasAvatar[a] ?? false;
      final avatarB = hasAvatar[b] ?? false;
      if (!avatarA && avatarB) return 1;
      if (avatarA && !avatarB) return -1;
      return 0;
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ChatStateScope.maybeOf(context);

    return Obx(() {
      final List<Handle> participants;
      final String? customAvatarPath;

      if (chatState != null) {
        // Reactive path: observables tracked by Obx — rebuilds on participant or avatar changes.
        participants = _sortedHandles(chatState.participants.map((hs) => hs.handle).toList());
        customAvatarPath = chatState.customAvatarPath.value;
      } else {
        // Static path: read once from the chat param — no subscription created.
        participants = _sortedHandles(chat?.handles.toList() ?? []);
        customAvatarPath = chat?.customAvatarPath;
      }

      if (participants.isEmpty) {
        return ContactAvatarWidget(
          handle: Handle(address: ''),
          size: size * SettingsSvc.settings.avatarScale.value,
          editable: false,
          scaleSize: false,
        );
      }

      final hide = SettingsSvc.settings.redactedMode.value && SettingsSvc.settings.hideContactInfo.value;
      final avatarSize = size * SettingsSvc.settings.avatarScale.value;
      final maxAvatars = SettingsSvc.settings.maxAvatarsInGroupWidget.value;
      final skin = SettingsSvc.settings.skin.value;

      if (customAvatarPath != null && !hide) {
        dynamic file = File(customAvatarPath);
        return CircleAvatar(
          key: ValueKey(customAvatarPath),
          radius: avatarSize / 2,
          backgroundImage: FileImage(file),
          backgroundColor: Colors.transparent,
        );
      }

      return SizedBox(
        width: avatarSize,
        height: avatarSize,
        child: participants.length > 1
            ? ThemeSwitcher(
                iOSSkin: Stack(
                  children: [
                    Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(avatarSize / 2),
                        color: context.theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    ...List.generate(
                      min(participants.length, maxAvatars),
                      (index) {
                        // Trig really paying off here
                        int realLength = min(participants.length, maxAvatars);
                        double padding = avatarSize * 0.08;
                        double angle = index / realLength * 2 * pi + pi / 4;
                        double adjustedWidth = avatarSize * (-0.07 * realLength + 1);
                        double innerRadius = avatarSize - adjustedWidth / 2 - 2 * padding;
                        double tileSize = adjustedWidth * 0.65;
                        double top = (avatarSize / 2) + (innerRadius / 2) * sin(angle + pi) - tileSize / 2;
                        double right = (avatarSize / 2) + (innerRadius / 2) * cos(angle + pi) - tileSize / 2;

                        // indicate more users than shown
                        if (index == maxAvatars - 1 && participants.length > maxAvatars) {
                          return Positioned(
                            top: top,
                            right: right,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(tileSize),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 2,
                                  sigmaY: 2,
                                ),
                                child: Container(
                                  width: tileSize,
                                  height: tileSize,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                                      border: Border.all(
                                          color: context.theme.colorScheme.surface, width: avatarSize * 0.01)),
                                  child: Icon(
                                    skin == Skins.iOS ? CupertinoIcons.group_solid : Icons.people,
                                    size: tileSize * 0.65,
                                    color: context.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        return Positioned(
                          top: top,
                          right: right,
                          child: ContactAvatarWidget(
                            key: Key("${participants[index].address}-contact-avatar-group-widget"),
                            handle: participants[index],
                            size: tileSize,
                            borderThickness: avatarSize * 0.01,
                            fontSize: adjustedWidth * 0.3,
                            editable: false,
                            scaleSize: false,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                materialSkin: Stack(
                  children: List.generate(
                      min(participants.length, 4),
                      (index) => Align(
                            alignment: _materialGeneration[min(participants.length, 4)]![2][index] as Alignment,
                            child: ContactAvatarWidget(
                              handle: participants[index],
                              size: avatarSize * (_materialGeneration[min(participants.length, 4)]![0] as double),
                              fontSize: avatarSize * (_materialGeneration[min(participants.length, 4)]![1] as double),
                              editable: editable,
                              scaleSize: false,
                            ),
                          )),
                ),
              )
            : ContactAvatarWidget(
                handle: participants.first,
                borderThickness: 0.1,
                size: avatarSize,
                preferHighResAvatar: true,
                fontSize: avatarSize * 0.5,
                editable: editable,
                scaleSize: false,
              ),
      );
    });
  }
}
