import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

class ReactionDetails extends StatelessWidget {
  const ReactionDetails({
    super.key,
    required this.reactions,
  });

  final List<Message> reactions;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            alignment: Alignment.center,
            height: 120,
            color: context.theme.colorScheme.surfaceContainerHighest
                .withAlpha(SettingsSvc.settings.skin.value == Skins.iOS ? 150 : 255),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: ListView.separated(
                shrinkWrap: true,
                physics: ThemeSwitcher.getScrollPhysics(),
                scrollDirection: Axis.horizontal,
                findChildIndexCallback: (key) => findChildIndexByKey(reactions, key, (item) => item.guid),
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final message = reactions[index];
                  final handle = message.handleRelation.target;
                  String? reactionName;
                  if (!SettingsSvc.settings.hideNamesForReactions.value) {
                    if (message.isFromMe!) {
                      reactionName = SettingsSvc.settings.userName.value;
                    } else if (handle != null) {
                      reactionName = HandleSvc.getOrCreateHandleState(handle).reactionDisplayName.value;
                    }
                  }
                  return Column(
                    key: ValueKey(message.guid!),
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10),
                        child: ContactAvatarWidget(
                          handle: handle,
                          borderThickness: 0.1,
                          editable: false,
                          fontSize: 22,
                        ),
                      ),
                      if (reactionName != null && reactionName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            reactionName,
                            style: context.theme.textTheme.bodySmall!
                                .copyWith(color: context.theme.colorScheme.onSurfaceVariant),
                          ),
                        )
                      else
                        const SizedBox(height: 8),
                      Container(
                        height: 28,
                        width: 28,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          color: message.isFromMe!
                              ? context.theme.colorScheme.primary
                              : context.theme.colorScheme.surfaceContainerHighest,
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 1.0,
                              color: context.theme.colorScheme.outline,
                            )
                          ],
                        ),
                        child: Padding(
                          padding: SettingsSvc.settings.skin.value == Skins.iOS && ReactionTypes.toList().contains(message.associatedMessageType?.replaceAll("-", ""))
                              ? const EdgeInsets.only(top: 8.0, left: 7.0, right: 7.0, bottom: 7.0)
                                  .add(EdgeInsets.only(right: message.associatedMessageType == "emphasize" ? 1 : 0))
                              : EdgeInsets.zero,
                          child: SettingsSvc.settings.skin.value == Skins.iOS && ReactionTypes.toList().contains(message.associatedMessageType?.replaceAll("-", ""))
                              ? SvgPicture.asset(
                                  'assets/reactions/${message.associatedMessageType}-black.svg',
                                  colorFilter: ColorFilter.mode(
                                    message.associatedMessageType == "love"
                                        ? Colors.pink
                                        : message.isFromMe!
                                            ? context.theme.colorScheme.onPrimary
                                            : context.theme.colorScheme.onSurfaceVariant,
                                    BlendMode.srcIn,
                                  ),
                                )
                              : Center(
                                  child: Builder(builder: (context) {
                                    final text = Text(
                                      ReactionTypes.emojiForReaction(message.associatedMessageType),
                                      style: const TextStyle(fontSize: 18, fontFamily: 'Apple Color Emoji'),
                                      textAlign: TextAlign.center,
                                    );
                                    if (message.associatedMessageType == "dislike") {
                                      return Transform(
                                        transform: Matrix4.identity()..rotateY(pi),
                                        alignment: FractionalOffset.center,
                                        child: text,
                                      );
                                    }
                                    return text;
                                  }),
                                ),
                        ),
                      )
                    ],
                  );
                },
                itemCount: reactions.length,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
