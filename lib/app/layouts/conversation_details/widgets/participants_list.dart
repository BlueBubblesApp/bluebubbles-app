import 'dart:async';

import 'package:bluebubbles/app/layouts/conversation_details/dialogs/add_participant.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/contact_tile.dart';
import 'package:bluebubbles/app/state/chat_state.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Widget that handles rendering the participants list with show more/less functionality
class ParticipantsList extends StatefulWidget {
  final Chat chat;

  const ParticipantsList({
    super.key,
    required this.chat,
  });

  @override
  State<ParticipantsList> createState() => _ParticipantsListState();
}

class _ParticipantsListState extends State<ParticipantsList> with ThemeHelpers {
  bool showMoreParticipants = false;
  StreamSubscription? _participantsSub;

  /// Returns the reactive ChatState for this chat, if available.
  ChatState? get _chatState => ChatsSvc.chatStates[widget.chat.guid];

  /// Current participants read from ChatState, falling back to widget.chat.people.
  List<Handle> get _currentParticipants {
    final state = _chatState;
    if (state != null) return state.participants.map((hs) => hs.handle).toList();
    return widget.chat.people;
  }

  bool get shouldShowMore => _currentParticipants.length > 5;

  List<Handle> get clippedParticipants =>
      showMoreParticipants ? _currentParticipants : _currentParticipants.take(5).toList();

  @override
  void initState() {
    super.initState();
    // Rebuild whenever the reactive participants list changes (e.g. after addParticipant).
    _participantsSub = _chatState?.participants.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _participantsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.chat.isGroup) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final participants = clippedParticipants;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final addMember = ListTile(
            mouseCursor: MouseCursor.defer,
            title: Text(
              "Add ${iOS ? "Member" : "people"}",
              style: context.theme.textTheme.bodyLarge!.copyWith(
                color: context.theme.colorScheme.primary,
              ),
            ),
            leading: Container(
              width: 40 * SettingsSvc.settings.avatarScale.value,
              height: 40 * SettingsSvc.settings.avatarScale.value,
              decoration: BoxDecoration(
                color: !iOS ? null : context.theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
                border: iOS
                    ? null
                    : Border.all(
                        color: context.theme.colorScheme.primary,
                        width: 3,
                      ),
              ),
              child: Icon(
                Icons.add,
                color: context.theme.colorScheme.primary,
                size: 20,
              ),
            ),
            onTap: () {
              showAddParticipant(context, widget.chat);
            },
          );

          if (index > participants.length) {
            if (SettingsSvc.settings.enablePrivateAPI.value &&
                widget.chat.isIMessage &&
                widget.chat.isGroup &&
                shouldShowMore) {
              return addMember;
            } else {
              return const SizedBox.shrink();
            }
          }

          if (index == participants.length) {
            if (shouldShowMore) {
              return ListTile(
                mouseCursor: MouseCursor.defer,
                onTap: () {
                  setState(() {
                    showMoreParticipants = !showMoreParticipants;
                  });
                },
                title: Text(
                  showMoreParticipants ? "Show less" : "Show more",
                  style: context.theme.textTheme.bodyLarge!.copyWith(
                    color: context.theme.colorScheme.primary,
                  ),
                ),
                leading: Container(
                  width: 40 * SettingsSvc.settings.avatarScale.value,
                  height: 40 * SettingsSvc.settings.avatarScale.value,
                  decoration: BoxDecoration(
                    color: !iOS ? null : context.theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                    border: iOS
                        ? null
                        : Border.all(
                            color: context.theme.colorScheme.primary,
                            width: 3,
                          ),
                  ),
                  child: Icon(
                    Icons.more_horiz,
                    color: context.theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
              );
            } else if (SettingsSvc.settings.enablePrivateAPI.value && widget.chat.isIMessage && widget.chat.isGroup) {
              return addMember;
            } else {
              return const SizedBox.shrink();
            }
          }

          return ContactTile(
            key: Key(participants[index].address),
            handle: participants[index],
            chat: widget.chat,
            canBeRemoved: widget.chat.isGroup && SettingsSvc.settings.enablePrivateAPI.value && widget.chat.isIMessage,
          );
        },
        childCount: participants.length + 2,
      ),
    );
  }
}
