import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

class ContactAvatarGroupWidget extends StatefulWidget {
  ContactAvatarGroupWidget({
    super.key,
    required this.chat,
    this.size = 40,
    this.editable = true,
  });
  final Chat chat;
  final double size;
  final bool editable;

  @override
  State<ContactAvatarGroupWidget> createState() => _ContactAvatarGroupWidgetState();
}

class _ContactAvatarGroupWidgetState extends OptimizedState<ContactAvatarGroupWidget> {
  late final List<Handle> participants = widget.chat.participants;
  final Map materialGeneration = {
    2: [24.5/40, 10.5/40, [Alignment.topRight, Alignment.bottomLeft]],
    3: [21.5/40, 9/40, [Alignment.bottomRight, Alignment.bottomLeft, Alignment.topCenter]],
    4: [1/2, 8.7/40, [Alignment.bottomRight, Alignment.bottomLeft, Alignment.topLeft, Alignment.topRight]],
  };

  @override
  void initState() {
    super.initState();
    participants.sort((a, b) {
      bool avatarA = a.contact?.avatar?.isNotEmpty ?? false;
      bool avatarB = b.contact?.avatar?.isNotEmpty ?? false;
      if (!avatarA && avatarB) return 1;
      if (avatarA && !avatarB) return -1;
      return 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return ContactAvatarWidget(
        handle: Handle(address: ''),
        size: widget.size * ss.settings.avatarScale.value,
        editable: false,
        scaleSize: false,
      );
    }

    return Obx(() {
        final hide = ss.settings.redactedMode.value && ss.settings.hideContactInfo.value;
        final avatarSize = widget.size * ss.settings.avatarScale.value;
        final maxAvatars = ss.settings.maxAvatarsInGroupWidget.value;

        if (widget.chat.customAvatarPath != null && !hide) {
          dynamic file = File(widget.chat.customAvatarPath!);
          return CircleAvatar(
            key: ValueKey(widget.chat.customAvatarPath!),
            radius: avatarSize / 2,
            backgroundImage: FileImage(file),
            backgroundColor: Colors.transparent,
          );
        }

        return Container(
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
                          color: context.theme.colorScheme.properSurface,
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
                          double size = adjustedWidth * 0.65;
                          double top = (avatarSize / 2) + (innerRadius / 2) * sin(angle + pi) - size / 2;
                          double right = (avatarSize / 2) + (innerRadius / 2) * cos(angle + pi) - size / 2;

                          // indicate more users than shown
                          if (index == maxAvatars - 1 && participants.length > maxAvatars) {
                            return Positioned(
                              top: top,
                              right: right,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(size),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 2,
                                    sigmaY: 2,
                                  ),
                                  child: Container(
                                    width: size,
                                    height: size,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: context.theme.colorScheme.properSurface.withOpacity(0.8),
                                      border: Border.all(color: context.theme.colorScheme.background, width: avatarSize * 0.01)
                                    ),
                                    child: Icon(
                                      ss.settings.skin.value == Skins.iOS ? CupertinoIcons.group_solid : Icons.people,
                                      size: size * 0.65,
                                      color: context.theme.colorScheme.properOnSurface.withOpacity(0.8),
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
                              size: size,
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
                    children: List.generate(min(participants.length, 4), (index) => Align(
                      alignment: materialGeneration[min(participants.length, 4)][2][index],
                      child: ContactAvatarWidget(
                        handle: participants[index],
                        size: avatarSize * materialGeneration[min(participants.length, 4)][0],
                        fontSize: avatarSize * materialGeneration[min(participants.length, 4)][1],
                        editable: widget.editable,
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
                  editable: widget.editable,
                  scaleSize: false,
                ),
        );
      },
    );
  }
}
