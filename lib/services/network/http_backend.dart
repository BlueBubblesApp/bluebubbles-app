
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';

class HttpBackend extends BackendService {
  @override
  Future<Chat> createChat(List<String> addresses, String? message, String service, {CancelToken? cancelToken}) async {
    var response = await http.createChat(addresses, message, service, cancelToken: cancelToken);
    return Chat.fromMap(response.data["data"]);
  }

  @override
  void init() { }

  @override
  void startedTyping(Chat c) {
    socket.sendMessage("started-typing", {"chatGuid": c.guid});
  }

  @override
  void stoppedTyping(Chat c){
    socket.sendMessage("stopped-typing", {"chatGuid": c.guid});
  }

  @override
  void updateTypingStatus(Chat c) {
    socket.sendMessage("update-typing-status", {"chatGuid": c.guid});
  }

   @override
  Future<Map<String, dynamic>> getAccountInfo() async {
    var result = await http.getAccountInfo();
    if (!isNullOrEmpty(result.data.isNotEmpty)!) {
      return result.data['data'];
    }
    return {};
  }

  @override
  Future<void> setDefaultHandle(String defaultHandle) async {
    await http.setAccountAlias(defaultHandle);
  }

  @override
  Future<Map<String, dynamic>> getAccountContact() async {
    if (ss.isMinBigSurSync) {
      final result2 = await http.getAccountContact();
      if (!isNullOrEmpty(result2.data.isNotEmpty)!) {
        return result2.data['data'];
      }
    }
    return {};
  }
  
  @override
  Future<Message> sendMessage(Chat c, Message m, {CancelToken? cancelToken}) async {
    if (m.attributedBody.isNotEmpty) {
      var response = await http.sendMultipart(
        c.guid,
        m.guid!,
        m.attributedBody.first.runs.map((e) => {
          "text": m.attributedBody.first.string.substring(e.range.first, e.range.first + e.range.last),
          "mention": e.attributes!.mention,
          "partIndex": e.attributes!.messagePart,
        }).toList(),
        subject: m.subject,
        selectedMessageGuid: m.threadOriginatorGuid,
        effectId: m.expressiveSendStyleId,
        partIndex: int.tryParse(m.threadOriginatorPart?.split(":").firstOrNull ?? ""),
      );
      return Message.fromMap(response.data["data"]);
    } else {
      var response = await http.sendMessage(c.guid,
          m.guid!,
          m.text!,
          subject: m.subject,
          method: (ss.settings.enablePrivateAPI.value
              && ss.settings.privateAPISend.value)
              || (m.subject?.isNotEmpty ?? false)
              || m.threadOriginatorGuid != null
              || m.expressiveSendStyleId != null
              ? "private-api" : "apple-script",
          selectedMessageGuid: m.threadOriginatorGuid,
          effectId: m.expressiveSendStyleId,
          partIndex: int.tryParse(m.threadOriginatorPart?.split(":").firstOrNull ?? ""),
          ddScan: m.text!.isURL, cancelToken: cancelToken);
      return Message.fromMap(response.data["data"]);
    }
  }
  
  @override
  Future<bool> renameChat(Chat chat, String newName) async {
    return (await http.updateChat(chat.guid, newName)).statusCode == 200;
  }

  @override
  Future<bool> chatParticipant(ParticipantOp op, Chat chat, String address) async {
    var method = op.name.toLowerCase();
    return (await http.chatParticipant(method, chat.guid, address)).statusCode == 200;
  }
  
  @override
  Future<bool> leaveChat(Chat chat) async {
    return (await http.leaveChat(chat.guid)).statusCode == 200;
  }
  
  @override
  Future<Message> sendTapback(Chat chat, Message selected, String reaction, int? repPart) async {
    return Message.fromMap((await http.sendTapback(chat.guid, selected.text ?? "", selected.guid!, reaction, partIndex: repPart)).data['data']);
  }
  
  @override
  Future<bool> markRead(Chat chat, bool notifyOthers) async {
    if (!notifyOthers) return true;
    return (await http.markChatRead(chat.guid)).statusCode == 200;
  }

  @override
  Future<bool> markUnread(Chat chat) async {
    return (await http.markChatUnread(chat.guid)).statusCode == 200;
  }

  @override
  HttpService? remoteService {
    return http;
  }

  @override
  bool get canLeaveChat {
    return ss.serverDetailsSync().item4 >= 226;
  }

  @override
  bool get canEditUnsend {
    return ss.isMinVenturaSync && ss.serverDetailsSync().item4 >= 148;
  }

  @override
  Future<Message?> unsend(Message msg, MessagePart part) async {
    var response = await http.unsend(msg.guid!, partIndex: part.part);
    if (response.statusCode != 200) {
      return null;
    }
    return Message.fromMap(response.data['data']);
  }

  @override
  Future<Message?> edit(Message msg, String text, int part) async {
    var response = await http.edit(msg.guid!, text, "Edited to: “$text", partIndex: part);
    if (response.statusCode != 200) {
      return null;
    }
    return Message.fromMap(response.data['data']);
  }

  @override
  Future<PlatformFile> downloadAttachment(Attachment att, {void Function(int p1, int p2)? onReceiveProgress, bool original = false, CancelToken? cancelToken}) async {
    var response = await http.downloadAttachment(att.guid!, onReceiveProgress: onReceiveProgress, original: original, cancelToken: cancelToken);
    if (response.statusCode != 200) {
      throw Exception("Bad!");
    }
    if (att.mimeType == "image/gif") {
      att.bytes = await fixSpeedyGifs(response.data);
    } else {
      att.bytes = response.data;
    }
    att.webUrl = response.requestOptions.path;
    return att.getFile();
  }

  @override
  Future<Message> sendAttachment(Chat c, Message m, bool isAudioMessage, Attachment attachment, {void Function(int p1, int p2)? onSendProgress, CancelToken? cancelToken}) async {
    var response = await http.sendAttachment(c.guid,
      attachment.guid!,
      attachment.getFile(),
      onSendProgress: onSendProgress,
      method: (ss.settings.enablePrivateAPI.value
          && ss.settings.privateAPIAttachmentSend.value)
          || (m.subject?.isNotEmpty ?? false)
          || m.threadOriginatorGuid != null
          || m.expressiveSendStyleId != null
          ? "private-api" : "apple-script",
      selectedMessageGuid: m.threadOriginatorGuid,
      effectId: m.expressiveSendStyleId,
      partIndex: int.tryParse(m.threadOriginatorPart?.split(":").firstOrNull ?? ""),
      isAudioMessage: isAudioMessage,
      cancelToken: cancelToken);
    if (response.statusCode != 200) {
      throw Exception("Failed to upload!");
    }
    return Message.fromMap(response.data['data']);
  }

  @override
  bool canCancelUploads() {
    return true;
  }

  @override
  Future<bool> canUploadGroupPhotos() async {
    return (await ss.isMinBigSur) && ss.serverDetailsSync().item4 >= 226;
  }

  @override
  Future<bool> setChatIcon(Chat chat, {void Function(int, int)? onSendProgress, CancelToken? cancelToken}) async {
    return (await http.setChatIcon(chat.guid, chat.customAvatarPath!, onSendProgress: onSendProgress, cancelToken: cancelToken)).statusCode == 200;
  }

  @override
  Future<bool> deleteChatIcon(Chat chat, {CancelToken? cancelToken}) async {
    return (await http.deleteChatIcon(chat.guid, cancelToken: cancelToken)).statusCode == 200;
  }

  @override
  bool supportsFocusStates() {
    return ss.isMinMontereySync;
  }

  @override
  Future<bool> downloadLivePhoto(Attachment att, String target, {void Function(int p1, int p2)? onReceiveProgress, CancelToken? cancelToken}) async {
    var response = await http.downloadLivePhoto(att.guid!, onReceiveProgress: onReceiveProgress, cancelToken: cancelToken);
    if (response.statusCode != 200) {
      return false;
    }
    final file = PlatformFile(
      name: target,
      size: response.data.length,
      bytes: response.data,
    );
    await as.saveToDisk(file);
    return true;
  }

  @override
  bool get canSchedule {
    return ss.serverDetailsSync().item4 >= 205;
  }

  @override
  bool get supportsFindMy {
    return ss.isMinCatalinaSync;
  }

  @override
  bool get canCreateGroupChats {
    return ss.canCreateGroupChatSync();
  }

  @override
  bool get supportsSmsForwarding {
    return true;
  }

  @override
  Future<bool> handleiMessageState(String address) async {
    final response = await http.handleiMessageState(address);
    return response.data["data"]["available"];
  }
}