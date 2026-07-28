import 'package:bluebubbles/app/components/m3e/m3e.dart';
import 'package:bluebubbles/app/layouts/conversation_details/dialogs/add_participant.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/contact_tile.dart';
import 'package:bluebubbles/app/state/chat_state.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The Material/Samsung members section — same [ContactTile] rows `ParticipantsList` uses for
/// iOS, contained in a connected-corner [M3ESection] instead of a flat, unbounded sliver list.
class ExpressiveParticipantsSection extends StatefulWidget {
  final Chat chat;

  const ExpressiveParticipantsSection({super.key, required this.chat});

  @override
  State<ExpressiveParticipantsSection> createState() => _ExpressiveParticipantsSectionState();
}

class _ExpressiveParticipantsSectionState extends State<ExpressiveParticipantsSection> {
  bool showMoreParticipants = false;

  Chat get chat => widget.chat;

  ChatState? get _chatState => ChatsSvc.chatStates[chat.guid];

  bool get _canAddPeople =>
      SettingsSvc.settings.enablePrivateAPI.value && chat.isIMessage && chat.isGroup;

  @override
  Widget build(BuildContext context) {
    if (!chat.isGroup) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Obx(() {
        final state = _chatState;
        final participants = state != null ? state.participants.map((hs) => hs.handle).toList() : chat.handles.toList();
        final shouldShowMore = participants.length > 5;
        final clipped = showMoreParticipants ? participants : participants.take(5).toList();
        final canBeRemoved = chat.isGroup && SettingsSvc.settings.enablePrivateAPI.value && chat.isIMessage;

        final children = <Widget>[
          for (final handle in clipped)
            ContactTile(
              key: Key(handle.address),
              handle: handle,
              chat: chat,
              canBeRemoved: canBeRemoved,
            ),
          if (shouldShowMore)
            _ShowMoreRow(
              expanded: showMoreParticipants,
              onTap: () => setState(() => showMoreParticipants = !showMoreParticipants),
            ),
          if (_canAddPeople)
            _AddPeopleRow(onTap: () => showAddParticipant(context, chat)),
        ];

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const M3ESectionHeader(label: "Members"),
            M3ESection(
              backgroundColor: context.tileColor,
              children: children,
            ),
          ],
        );
      }),
    );
  }
}

class _ShowMoreRow extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;

  const _ShowMoreRow({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  expanded ? "Show less" : "Show more",
                  style: context.theme.textTheme.bodyLarge?.copyWith(color: context.theme.colorScheme.primary),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: M3EMotion.spatialFast.duration,
                  curve: M3EMotion.spatialFast.curve,
                  child: Icon(Icons.expand_more, color: context.theme.colorScheme.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddPeopleRow extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPeopleRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return M3EListTile(
      icon: Icons.person_add,
      title: "Add people",
      onTap: onTap,
    );
  }
}
