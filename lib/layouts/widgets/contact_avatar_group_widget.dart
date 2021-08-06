import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ContactAvatarGroupWidget extends StatefulWidget {
  ContactAvatarGroupWidget({Key? key, this.size = 40, this.editable = true, this.onTap, required this.chat})
      : super(key: key);
  final Chat chat;
  final double size;
  final bool editable;
  final Function()? onTap;

  @override
  _ContactAvatarGroupWidgetState createState() => _ContactAvatarGroupWidgetState();
}

class _ContactAvatarGroupWidgetState extends State<ContactAvatarGroupWidget> {
  RxList<Handle> participants = RxList<Handle>();

  @override
  Widget build(BuildContext context) {
    participants = widget.chat.participants.obs;

    participants.sort((a, b) {
      bool avatarA = ContactManager().getCachedContactSync(a.address)?.avatar?.isNotEmpty ?? false;
      bool avatarB = ContactManager().getCachedContactSync(b.address)?.avatar?.isNotEmpty ?? false;
      if (!avatarA && avatarB) return 1;
      if (avatarA && !avatarB) return -1;
      return 0;
    });

    for (Handle participant in participants) {
      if (!(ContactManager().handleToContact[participant]?.avatar?.isNotEmpty ?? false)) {}
    }

    if (participants.length == 0) {
      return Container(
        width: widget.size,
        height: widget.size,
      );
    }

    return Obx(
      () => Container(
        width: widget.size,
        height: widget.size,
        child: participants.length > 1
            ? ThemeSwitcher(
                iOSSkin: Obx(
                  () {
                    int maxAvatars = SettingsManager().settings.maxAvatarsInGroupWidget.value;
                    return Stack(
                      children: [
                        Container(
                          width: widget.size,
                          height: widget.size,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(widget.size / 2),
                            color: context.theme.accentColor.withOpacity(0.6),
                          ),
                        ),
                        ...List.generate(
                          min(participants.length, maxAvatars),
                          (index) {
                            // Trig really paying off here
                            int realLength = min(participants.length, maxAvatars);
                            double padding = widget.size * 0.08;
                            double angle = index / realLength * 2 * pi + pi / 4;
                            double adjustedWidth = widget.size * (-0.07 * realLength + 1);
                            double innerRadius = widget.size - adjustedWidth / 2 - 2 * padding;
                            double size = adjustedWidth * 0.65;
                            double top = (widget.size / 2) + (innerRadius / 2) * sin(angle + pi) - size / 2;
                            double right = (widget.size / 2) + (innerRadius / 2) * cos(angle + pi) - size / 2;
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
                                        borderRadius: BorderRadius.circular(size),
                                        color: context.theme.accentColor.withOpacity(0.8),
                                      ),
                                      child: Icon(
                                        Icons.people,
                                        size: size * 0.65,
                                        color: context.textTheme.subtitle1!.color!.withOpacity(0.8),
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
                                handle: participants[index],
                                size: size,
                                borderThickness: widget.size * 0.01,
                                fontSize: adjustedWidth * 0.3,
                                editable: false,
                                onTap: widget.onTap,
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
                materialSkin: Builder(
                  builder: (context) {
                    if (participants.length == 2) {
                      return Stack(
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: ContactAvatarWidget(
                              handle: participants[0],
                              size: 24.5,
                              fontSize: 10.5,
                              editable: widget.editable,
                              onTap: widget.onTap,
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: ContactAvatarWidget(
                              handle: participants[1],
                              size: 24.5,
                              fontSize: 10.5,
                              editable: widget.editable,
                              onTap: widget.onTap,
                            ),
                          ),
                        ],
                      );
                    } else if (participants.length == 3) {
                      return Stack(
                        children: [
                          Align(
                            alignment: Alignment.bottomRight,
                            child: ContactAvatarWidget(
                              handle: participants[0],
                              size: 21.5,
                              fontSize: 9,
                              editable: widget.editable,
                              onTap: widget.onTap,
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: ContactAvatarWidget(
                              handle: participants[1],
                              size: 21.5,
                              fontSize: 9,
                              editable: widget.editable,
                              onTap: widget.onTap,
                            ),
                          ),
                          Align(
                            alignment: Alignment.topCenter,
                            child: ContactAvatarWidget(
                              handle: participants[2],
                              size: 21.5,
                              fontSize: 9,
                              editable: widget.editable,
                              onTap: widget.onTap,
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Stack(
                        children: [
                          Align(
                            alignment: Alignment.bottomRight,
                            child: ContactAvatarWidget(
                              handle: participants[0],
                              size: 20,
                              fontSize: 8.7,
                              editable: widget.editable,
                              onTap: widget.onTap,
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: ContactAvatarWidget(
                              handle: participants[1],
                              size: 20,
                              fontSize: 8.7,
                              editable: widget.editable,
                              onTap: widget.onTap,
                            ),
                          ),
                          Align(
                            alignment: Alignment.topLeft,
                            child: ContactAvatarWidget(
                              handle: participants[2],
                              size: 20,
                              fontSize: 8.7,
                              editable: widget.editable,
                              onTap: widget.onTap,
                            ),
                          ),
                          Align(
                            alignment: Alignment.topRight,
                            child: ContactAvatarWidget(
                              handle: participants[3],
                              size: 20,
                              fontSize: 8.7,
                              editable: widget.editable,
                              onTap: widget.onTap,
                            ),
                          ),
                        ],
                      );
                    }
                  },
                ),
                samsungSkin: Builder(
                  builder: (context) {
                    if (participants.length == 2) {
                      return Stack(
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: ContactAvatarWidget(
                              handle: participants[0],
                              size: 24.5,
                              fontSize: 10.5,
                              editable: widget.editable,
                              onTap: widget.onTap,
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: ContactAvatarWidget(
                              handle: participants[1],
                              size: 24.5,
                              fontSize: 10.5,
                              editable: widget.editable,
                              onTap: widget.onTap,
                            ),
                          ),
                        ],
                      );
                    } else if (participants.length == 3) {
                      return Stack(
                        children: [
                          Align(
                            alignment: Alignment.bottomRight,
                            child: ContactAvatarWidget(
                              handle: participants[0],
                              size: 21.5,
                              fontSize: 9,
                              editable: widget.editable,
                              onTap: widget.onTap,
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: ContactAvatarWidget(
                              handle: participants[1],
                              size: 21.5,
                              fontSize: 9,
                              editable: widget.editable,
                              onTap: widget.onTap,
                            ),
                          ),
                          Align(
                            alignment: Alignment.topCenter,
                            child: ContactAvatarWidget(
                              handle: participants[2],
                              size: 21.5,
                              fontSize: 9,
                              editable: widget.editable,
                              onTap: widget.onTap,
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Stack(
                        children: [
                          Align(
                            alignment: Alignment.bottomRight,
                            child: ContactAvatarWidget(
                              handle: participants[0],
                              size: 20,
                              fontSize: 8.7,
                              editable: widget.editable,
                              onTap: widget.onTap,
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: ContactAvatarWidget(
                              handle: participants[1],
                              size: 20,
                              fontSize: 8.7,
                              editable: widget.editable,
                              onTap: widget.onTap,
                            ),
                          ),
                          Align(
                            alignment: Alignment.topLeft,
                            child: ContactAvatarWidget(
                              handle: participants[2],
                              size: 20,
                              fontSize: 8.7,
                              editable: widget.editable,
                              onTap: widget.onTap,
                            ),
                          ),
                          Align(
                            alignment: Alignment.topRight,
                            child: ContactAvatarWidget(
                              handle: participants[3],
                              size: 20,
                              fontSize: 8.7,
                              editable: widget.editable,
                              onTap: widget.onTap,
                            ),
                          ),
                        ],
                      );
                    }
                  },
                ),
              )
            : ContactAvatarWidget(
                handle: participants.first,
                borderThickness: 0.1,
                size: widget.size,
                fontSize: widget.size * 0.5,
                editable: widget.editable,
                onTap: widget.onTap,
              ),
      ),
    );
  }
}
