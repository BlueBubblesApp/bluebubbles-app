import 'dart:async';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/app/widgets/components/reaction.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/widgets.dart';

class MessageHelper {
  static Future<List<Message>> bulkAddMessages(Chat? chat, List<dynamic> messages,
      {bool checkForLatestMessageText = true, Function(int progress, int length)? onProgress}) async {
    // Create master list for all the messages and a chat cache
    List<Message> _messages = <Message>[];
    Map<String, Chat> chats = <String, Chat>{};

    // Add the chat in the cache and save it if it hasn't been saved yet
    if (chat?.guid != null) {
      chats[chat!.guid] = chat;
      if (chat.id == null) {
        chat = chat.save();
      }
    }

    // Iterate over each message to parse it
    int index = 0;
    for (dynamic item in messages) {
      if (onProgress != null) {
        onProgress(_messages.length, messages.length);
      }

      // Pull the chats out of the message, if there isnt a default
      Chat? msgChat = chat;
      if (msgChat == null) {
        List<Chat> msgChats = (item['chats'] as List? ?? []).map((e) => Chat.fromMap(e)).toList();
        msgChat = msgChats.isNotEmpty ? msgChats.first : null;

        // If there is a cached chat, get it. Otherwise, save the new one
        if (msgChat != null && chats.containsKey(msgChat.guid)) {
          msgChat = chats[msgChat.guid];
        } else if (msgChat?.guid != null) {
          msgChat!.save();
          chats[msgChat.guid] = msgChat;
        }
      }

      // If we can't get a chat from the data, skip the message
      if (msgChat == null) continue;

      Message message = Message.fromMap(item);
      Message? existing = Message.findOne(guid: message.guid);
      await msgChat.addMessage(
        message,
        changeUnreadStatus: false,
        checkForMessageText: checkForLatestMessageText,
      );

      // Artificial await to prevent lag
      await Future.delayed(Duration(milliseconds: 10));

      if (existing != null) {
        message = existing;
      }

      // Create the attachments
      List<dynamic> attachments = item['attachments'];
      for (dynamic attachmentItem in attachments) {
        Attachment file = Attachment.fromMap(attachmentItem);
        file.save(message);
      }

      // Add message to the "master list"
      _messages.add(message);

      // Every 50 messages synced, who a message
      index += 1;
      if (index % 50 == 0) {
        Logger.info('Saved $index of ${messages.length} messages', tag: "BulkIngest");
      } else if (index == messages.length) {
        Logger.info('Saved ${messages.length} messages', tag: "BulkIngest");
      }
    }

    // Return all the synced messages
    return _messages;
  }

  static Future<void> handleNotification(Message message, Chat chat, {bool findExisting = true}) async {
    // See if there is an existing message for the given GUID
    if (findExisting && Message.findOne(guid: message.guid) != null) return;
    // if needing to mute
    if (chat.shouldMuteNotification(message)) return;
    // if from me
    if (message.isFromMe! || message.handle == null) return;
    // if the chat is active
    if (ls.isAlive && cm.isChatActive(chat.guid)) return;
    // if app is alive, on chat list, but notifying on chat list is disabled
    if (ls.isAlive && cm.activeChat == null && !ss.settings.notifyOnChatList.value) {
      chat.toggleHasUnread(true);
      return;
    }
    await notif.createNotification(chat, message);
  }

  static String getNotificationText(Message message, {bool withSender = false}) {
    if (message.isGroupEvent) return message.groupEventText;
    String sender = !withSender ? "" : "${message.isFromMe! ? "You" : message.handle?.displayName ?? "Someone"}: ";

    if (message.isInteractive) {
      return "$sender${message.interactiveText}";
    }

    if (isNullOrEmpty(message.fullText)! && !message.hasAttachments) {
      return "${sender}Empty message";
    }

    if (message.expressiveSendStyleId == "com.apple.MobileSMS.expressivesend.invisibleink") {
      return "Message sent with Invisible Ink";
    }

    // If there are attachments, return the number of attachments
    if (message.realAttachments.isNotEmpty) {
      int aCount = message.realAttachments.length;
      // Build the attachment output by counting the attachments
      String output = "Attachment${aCount > 1 ? "s" : ""}";
      return "$output: ${_getAttachmentText(message.realAttachments)}";
    } else if (!isNullOrEmpty(message.associatedMessageGuid)!) {
      // It's a reaction message, get the sender
      String sender = message.isFromMe! ? "You" : message.handle?.displayName ?? "Someone";
      // fetch the associated message object
      Message? associatedMessage = Message.findOne(guid: message.associatedMessageGuid);
      if (associatedMessage != null) {
        // grab the verb we'll use from the reactionToVerb map
        String? verb = ReactionTypes.reactionToVerb[message.associatedMessageType];
        // we need to check balloonBundleId first because for some reason
        // game pigeon messages have the text "�"
        if (associatedMessage.isInteractive) {
          return "$sender $verb ${message.interactiveText}";
          // now we check if theres a subject or text and construct out message based off that
        } else if (associatedMessage.expressiveSendStyleId == "com.apple.MobileSMS.expressivesend.invisibleink") {
          return "$sender $verb a message with Invisible Ink";
        } else if (!isNullOrEmpty(message.fullText)!) {
          return '$sender $verb “${message.fullText}”';
          // if it has an attachment, we should fetch the attachments and get the attachment text
        } else if (associatedMessage.hasAttachments) {
          return '$sender $verb ${_getAttachmentText(associatedMessage.fetchAttachments()!)}';
        }
      }
      // if we can't fetch the associated message for some reason
      // (or none of the above conditions about it are true)
      // then we should fallback to unparsed reaction messages
      Logger.info("Couldn't fetch associated message for message: ${message.guid}");
      return "$sender ${message.text}";
    } else {
      // It's all other message types
      return sender + message.fullText;
    }
  }

  // returns the attachments as a string
  static String _getAttachmentText(List<Attachment?> attachments) {
    Map<String, int> counts = {};
    for (Attachment? attachment in attachments) {
      String? mime = attachment!.mimeType;
      String key;
      if (mime == null) {
        key = "link";
      } else if (mime.contains("vcard")) {
        key = "contact card";
      } else if (mime.contains("location")) {
        key = "location";
      } else if (mime.contains("contact")) {
        key = "contact";
      } else if (mime.contains("video")) {
        key = "movie";
      } else if (mime.contains("image/gif")) {
        key = "GIF";
      } else if (mime.contains("application/pdf")) {
        key = "PDF";
      } else {
        key = mime.split("/").first;
      }

      int current = counts.containsKey(key) ? counts[key]! : 0;
      counts[key] = current + 1;
    }

    List<String> attachmentStr = [];
    counts.forEach((key, value) {
      attachmentStr.add("$value $key${value > 1 ? "s" : ""}");
    });
    return attachmentStr.join(attachmentStr.length == 2 ? " & " : ", ");
  }

  /// Removes duplicate associated message guids from a list of [associatedMessages]
  static List<Message> normalizedAssociatedMessages(List<Message> associatedMessages) {
    Set<int> guids = associatedMessages.map((e) => e.handleId ?? 0).toSet();
    List<Message> normalized = [];

    for (Message message in associatedMessages.reversed.toList()) {
      if (!ReactionTypes.toList().contains(message.associatedMessageType)) {
        normalized.add(message);
      } else if (guids.remove(message.handleId ?? 0)) {
        normalized.add(message);
      }
    }
    return normalized;
  }

  static bool shouldShowBigEmoji(String text) {
    if (isNullOrEmptyString(text)) return false;
    if (text.codeUnits.length == 1 && text.codeUnits.first == 9786) return true;

    final darkSunglasses = RegExp('\u{1F576}');
    if (emojiRegex.firstMatch(text) == null && !text.contains(darkSunglasses)) return false;

    List<RegExpMatch> matches = emojiRegex.allMatches(text).toList();
    List<String> items = matches.map((m) => m.toString()).toList();

    String replaced = text.replaceAll(emojiRegex, "").replaceAll(String.fromCharCode(65039), "").replaceAll(darkSunglasses, "").trim();
    return items.length <= 3 && replaced.isEmpty;
  }

  static List<TextSpan> buildEmojiText(String text, TextStyle style) {
    if (!fs.fontExistsOnDisk.value) {
      return [
        TextSpan(
          text: text,
          style: style,
        )
      ];
    }

    RegExp _emojiRegex = RegExp("${emojiRegex.pattern}|\u{1F576}");
    List<RegExpMatch> matches = _emojiRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return [
        TextSpan(
          text: text,
          style: style,
        )
      ];
    }

    final children = <TextSpan>[];
    int previousEnd = 0;
    for (int i = 0; i < matches.length; i++) {
      // Before the emoji
      if (previousEnd <= matches[i].start) {
        String chunk = text.substring(previousEnd, matches[i].start);
        children.add(
          TextSpan(
            text: chunk,
            style: style,
          ),
        );
        previousEnd += chunk.length;
      }

      // The emoji
      String chunk = text.substring(matches[i].start, matches[i].end);

      // Add stringed emoji
      while (i + 1 < matches.length && matches[i + 1].start == matches[i].end) {
        chunk += text.substring(matches[++i].start, matches[i].end);
      }
      children.add(
        TextSpan(
          text: chunk,
          style: style.apply(fontFamily: "Apple Color Emoji"),
        ),
      );
      previousEnd += chunk.length;
    }
    if (previousEnd < text.length) {
      children.add(
          TextSpan(
            text: text.substring(previousEnd),
            style: style,
          )
      );
    }

    return children;
  }
}