import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

/// Renders a native Apple Poll message (see POLL_NOTES.md for the reverse
/// engineered payload shapes this consumes).
///
/// Not wired up yet — see the commented-out case in interactive_holder.dart.
class PollMessage extends StatefulWidget {
  final iMessageAppData data;

  const PollMessage({
    super.key,
    required this.data,
  });

  @override
  State<StatefulWidget> createState() => _PollMessageState();
}

class _PollMessageState extends State<PollMessage> with AutomaticKeepAliveClientMixin {
  iMessageAppData get data => widget.data;
  dynamic get file => File(content.path!);
  dynamic content;

  late MessageState _ms;
  MessageState get controller => _ms;

  @override
  void initState() {
    super.initState();
    _ms = MessageStateScope.readStateOnce(context);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final message = controller.message;
    // The poll's root message guid — this message IS the root if it has no
    // associatedMessageGuid, otherwise it's a vote/options-update pointing at one.
    final rootGuid = message.associatedMessageGuid ?? message.guid;

    return Obx(() {
      // Observing associatedMessages here registers the Obx dependency so new
      // votes/options-updates trigger a rebuild (message.pollVoteTally /
      // .pollCurrentOptions below read the same underlying data, kept in sync
      // by MessageState.addAssociatedMessageInternal).
      controller.associatedMessages.length;
      final canonicalGuid = rootGuid == null ? null : controller.cvController?.pollCanonicalMessageGuid[rootGuid];

      // If a newer options-update message has superseded this bubble as the
      // canonical place to render the live poll, show a compact placeholder
      // instead of duplicating the full interactive poll UI.
      if (canonicalGuid != null && canonicalGuid != message.guid) {
        return Padding(
          padding: const EdgeInsets.all(15.0),
          child: Text(
            "Poll updated",
            style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline),
          ),
        );
      }

      return _buildPoll(context, message);
    });
  }

  Widget _buildPoll(BuildContext context, Message message) {
    final options = message.pollCurrentOptions;
    final tally = message.pollVoteTally;
    final myVote = message.pollMyVoteOptionIdentifier;
    final totalVotes = tally.values.fold<int>(0, (a, b) => a + b);

    // No options-update has arrived yet for this poll — fall back to the
    // same generic image + caption presentation used for other interactive
    // types until real option data is available.
    if (options.isEmpty) {
      return _buildFallback(context);
    }

    // The poll question isn't reliably present in any reverse-engineered
    // payload sample (see POLL_NOTES.md) — degrade to a generic label rather
    // than assume a field that may not exist.
    final title = message.latestPollOptionsUpdateMessage?.pollPayload?.optionsUpdate?.title ??
        (isNullOrEmpty(data.userInfo?.caption) ? null : data.userInfo!.caption) ??
        "Poll";

    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.theme.textTheme.bodyLarge!.apply(fontWeightDelta: 2),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          for (final option in options) _buildOption(context, option, tally, totalVotes, myVote),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context,
    PollOption option,
    Map<String, int> tally,
    int totalVotes,
    String? myVote,
  ) {
    final votes = tally[option.optionIdentifier] ?? 0;
    final percent = totalVotes == 0 ? 0.0 : votes / totalVotes;
    final isMine = option.optionIdentifier == myVote;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          if (isMine) Icon(Icons.check_circle, size: 16, color: context.theme.colorScheme.primary),
          if (isMine) const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.text.trim(),
                  style: context.theme.textTheme.bodyMedium!
                      .copyWith(fontWeight: isMine ? FontWeight.bold : FontWeight.normal),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 4,
                    backgroundColor: context.theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "$votes",
            style: context.theme.textTheme.labelMedium!.copyWith(color: context.theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    if (content == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final attachment = MessageStateScope.messageOf(context).dbAttachments.firstOrNull;
        if (attachment != null) {
          content = AttachmentsSvc.getContent(attachment, autoDownload: true, onComplete: (file) {
            if (mounted) {
              setState(() {
                content = file;
              });
            }
          });
          if (content != null && mounted) setState(() {});
        }
      });
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (content is PlatformFile && content.bytes != null)
          Image.memory(
            content.bytes!,
            gaplessPlayback: true,
            filterQuality: FilterQuality.none,
            errorBuilder: (context, object, stacktrace) => Center(
              heightFactor: 1,
              child: Text("Failed to display image", style: context.theme.textTheme.bodyLarge),
            ),
          ),
        if (content is PlatformFile && content.bytes == null && content.path != null)
          Image.file(
            file,
            gaplessPlayback: true,
            filterQuality: FilterQuality.none,
            errorBuilder: (context, object, stacktrace) => Center(
              heightFactor: 1,
              child: Text("Failed to display image", style: context.theme.textTheme.bodyLarge),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(15.0),
          child: Text(
            isNullOrEmpty(data.userInfo?.caption) ? (data.ldText ?? "Poll") : data.userInfo!.caption!,
            style: context.theme.textTheme.bodyLarge!.apply(fontWeightDelta: 2),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
