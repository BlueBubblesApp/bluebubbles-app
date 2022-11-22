import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_details/dialogs/add_participant.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/chat_info.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/chat_options.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/media_gallery_card.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/contact_tile.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class ConversationDetails extends StatefulWidget {
  final Chat chat;

  ConversationDetails({Key? key, required this.chat}) : super(key: key);

  @override
  State<ConversationDetails> createState() => _ConversationDetailsState();
}

class _ConversationDetailsState extends OptimizedState<ConversationDetails> with WidgetsBindingObserver {
  List<Attachment> attachmentsForChat = <Attachment>[];
  bool showMoreParticipants = false;
  late Chat chat = widget.chat;
  late StreamSubscription<Query<Chat>> sub;

  bool get shouldShowMore => chat.participants.length > 5;
  List<Handle> get clippedParticipants => showMoreParticipants
      ? chat.participants
      : chat.participants.take(5).toList();

  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      final chatQuery = chatBox.query(Chat_.guid.equals(chat.guid)).watch();
      sub = chatQuery.listen((Query<Chat> query) {
        final _chat = chatBox.get(chat.id!);
        if (_chat != null) {
          final update = _chat.getTitle() != chat.title || _chat.participants.length != chat.participants.length;
          chat = _chat.merge(chat);
          if (update) {
            setState(() {});
          }
        }
      });
    }

    updateObx(() {
      fetchAttachments();
    });
  }

  @override
  void dispose() {
    sub.cancel();
    super.dispose();
  }

  void fetchAttachments() {
    if (kIsWeb) return;
    chat.getAttachmentsAsync().then((value) {
      final attachments = value.where((e) => !(e.message.target?.isGroupEvent ?? true)).take(25);
      for (Attachment a in attachments) {
        a.message.target?.handle = chat.participants.firstWhereOrNull((e) => e.id == a.message.target?.handleId);
      }
      setState(() {
        attachmentsForChat = attachments.toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: ss.settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Theme(
        data: context.theme.copyWith(
          // in case some components still use legacy theming
          primaryColor: context.theme.colorScheme.bubble(context, chat.isIMessage),
          colorScheme: context.theme.colorScheme.copyWith(
            primary: context.theme.colorScheme.bubble(context, chat.isIMessage),
            onPrimary: context.theme.colorScheme.onBubble(context, chat.isIMessage),
            surface: ss.settings.monetTheming.value == Monet.full
                ? null
                : (context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor,
            onSurface: ss.settings.monetTheming.value == Monet.full
                ? null
                : (context.theme.extensions[BubbleColors] as BubbleColors?)?.onReceivedBubbleColor,
          ),
        ),
        child: Obx(() => SettingsScaffold(
          headerColor: headerColor,
          title: "Details",
          tileColor: tileColor,
          initialHeader: null,
          iosSubtitle: iosSubtitle,
          materialSubtitle: materialSubtitle,
          bodySlivers: [
            SliverToBoxAdapter(
              child: ChatInfo(chat: chat),
            ),
            if (chat.isGroup)
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final addMember = ListTile(
                    title: Text("Add Member", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                    leading: Container(
                      width: 40 * ss.settings.avatarScale.value,
                      height: 40 * ss.settings.avatarScale.value,
                      decoration: BoxDecoration(
                        color: context.theme.colorScheme.properSurface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                          Icons.add,
                          color: context.theme.colorScheme.primary,
                          size: 20
                      ),
                    ),
                    onTap: () {
                      showAddParticipant(context, chat);
                    },
                  );

                  if (index > clippedParticipants.length) {
                    if (ss.settings.enablePrivateAPI.value && chat.isIMessage && chat.isGroup && shouldShowMore) {
                      return addMember;
                    } else {
                      return const SizedBox.shrink();
                    }
                  }
                  if (index == clippedParticipants.length) {
                    if (shouldShowMore) {
                      return ListTile(
                        onTap: () {
                          setState(() {
                            showMoreParticipants = !showMoreParticipants;
                          });
                        },
                        title: Text(
                          showMoreParticipants ? "Show less" : "Show more",
                          style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary),
                        ),
                        leading: Container(
                          width: 40 * ss.settings.avatarScale.value,
                          height: 40 * ss.settings.avatarScale.value,
                          decoration: BoxDecoration(
                            color: context.theme.colorScheme.properSurface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.more_horiz,
                            color: context.theme.colorScheme.primary,
                            size: 20
                          ),
                        ),
                      );
                    } else if (ss.settings.enablePrivateAPI.value && chat.isIMessage && chat.isGroup) {
                      return addMember;
                    } else {
                      return const SizedBox.shrink();
                    }
                  }

                  return ContactTile(
                    key: Key(chat.participants[index].address),
                    handle: chat.participants[index],
                    chat: chat,
                    canBeRemoved: chat.participants.length > 1
                        && ss.settings.enablePrivateAPI.value
                        && chat.isIMessage,
                  );
                }, childCount: clippedParticipants.length + 2),
              ),
            const SliverPadding(
              padding: EdgeInsets.symmetric(vertical: 10),
            ),
            ChatOptions(chat: chat),
            if (!kIsWeb)
              SliverPadding(
                padding: const EdgeInsets.only(top: 20, bottom: 10, left: 15),
                sliver: SliverToBoxAdapter(
                  child: Text("MEDIA", style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline)),
                ),
              ),
            if (!kIsWeb)
              SliverPadding(
                padding: const EdgeInsets.all(10),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: max(2, ns.width(context) ~/ 200),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, int index) {
                      return MediaGalleryCard(
                        attachment: attachmentsForChat[index],
                      );
                    },
                    childCount: attachmentsForChat.length,
                  ),
                ),
              ),
            const SliverPadding(
              padding: EdgeInsets.only(top: 50),
            ),
          ],
        ))
      ),
    );
  }
}
