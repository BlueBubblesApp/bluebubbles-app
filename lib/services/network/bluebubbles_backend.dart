import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/server_details.dart';
import 'package:bluebubbles/services/backend/interfaces/send_message_interface.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:dio/dio.dart';

/// The stock [BackendService]: talks to a BlueBubbles server over HTTP, with
/// the macOS Messages app doing the actual sending.
///
/// Every BlueBubbles-server-specific fact lives here — REST response shapes,
/// server version gates, macOS version gates, and the private-api/apple-script
/// transport choice. Nothing above this class needs to know any of it.
class BlueBubblesBackend implements BackendService {
  /// [serverDetails] and [privateApiEnabled] default to reading the live
  /// [SettingsService]. They are injectable so the capability getters — which
  /// are pure functions of those two inputs — can be exercised without standing
  /// up GetIt, the database, or a server connection.
  BlueBubblesBackend({
    ServerDetails Function()? serverDetails,
    bool Function()? privateApiEnabled,
  })  : _serverDetailsOf = serverDetails ?? (() => SettingsSvc.serverDetails),
        _privateApiEnabledOf = privateApiEnabled ?? (() => SettingsSvc.settings.enablePrivateAPI.value);

  final ServerDetails Function() _serverDetailsOf;
  final bool Function() _privateApiEnabledOf;

  @override
  Future<void> init() async {}

  @override
  HttpService? get remoteService => HttpSvc;

  ServerDetails get _server => _serverDetailsOf();

  bool get _privateApi => _privateApiEnabledOf();

  // ── Capabilities ───────────────────────────────────────────────────────────

  @override
  bool get canEditUnsend => _server.isMinVentura && _server.supportsEditAndUnsend;

  @override
  bool get canSchedule => _server.supportsScheduledMessages;

  @override
  bool get canSendSubject => _server.supportsSubjectLines;

  @override
  bool get canLeaveChat => _privateApi && _server.supportsGroupChatManagement;

  @override
  bool get canCreateGroupChats => SettingsSvc.canCreateGroupChatSync();

  @override
  bool get canManageGroupChat => _privateApi && _server.isMinBigSur && _server.supportsGroupChatManagement;

  @override
  bool get canCancelUploads => true;

  @override
  bool get supportsFocusStates => _server.isMinMonterey;

  @override
  bool get supportsFindMy => _server.isMinCatalina;

  @override
  bool get supportsSmsForwarding => true;

  @override
  bool get supportsRichSend => _privateApi;

  /// Sonoma and newer generate link previews server-side, so the client only
  /// has to scan for URLs on older servers.
  @override
  bool get needsClientSideUrlPreview => !_server.isMinSonoma;

  @override
  bool get canHardDelete => false;

  // ── Sending ────────────────────────────────────────────────────────────────

  /// Returns `'private-api'` if [m] must be sent via the Private API,
  /// `'apple-script'` otherwise.
  ///
  /// Private API is required when the user has it globally enabled AND the
  /// per-type setting is on, or when the message uses a feature only pAPI
  /// supports (subject, thread originator, or expressive effect).
  String _resolveMethod(Message m, {bool forAttachment = false}) {
    final papiEnabled = SettingsSvc.settings.enablePrivateAPI.value;
    final papiSend = forAttachment
        ? SettingsSvc.settings.privateAPIAttachmentSend.value
        : SettingsSvc.settings.privateAPISend.value;
    if ((papiEnabled && papiSend) ||
        (m.subject?.isNotEmpty ?? false) ||
        m.threadOriginatorGuid != null ||
        m.expressiveSendStyleId != null) {
      return 'private-api';
    }
    return 'apple-script';
  }

  int? _originatorPart(Message m) => int.tryParse(m.threadOriginatorPart?.split(':').firstOrNull ?? '');

  @override
  Future<Message> sendText(Chat chat, Message message, {CancelToken? cancelToken}) async {
    final data = await SendMessageInterface.sendTextMessage(
      chatGuid: chat.guid,
      tempGuid: message.guid!,
      message: message.text!,
      method: _resolveMethod(message),
      selectedMessageGuid: message.threadOriginatorGuid,
      effectId: message.expressiveSendStyleId,
      subject: message.subject,
      partIndex: _originatorPart(message),
      ddScan: needsClientSideUrlPreview && message.text!.hasUrl,
    );
    return Message.fromMap(data['data']);
  }

  @override
  Future<Message> sendTapback(
    Chat chat,
    Message message,
    Message selected,
    String reaction, {
    CancelToken? cancelToken,
  }) async {
    final data = await SendMessageInterface.sendTapback(
      chatGuid: chat.guid,
      selectedMessageText: selected.text ?? '',
      selectedMessageGuid: selected.guid!,
      reaction: reaction,
      partIndex: message.associatedMessagePart,
    );
    return Message.fromMap(data['data']);
  }

  @override
  Future<Message> sendMultipart(Chat chat, Message message, {CancelToken? cancelToken}) async {
    final body = message.attributedBody.first;
    final parts = body.runs
        .map(
          (e) => {
            'text': body.string.substring(e.range.first, e.range.first + e.range.last),
            'mention': e.attributes!.mention,
            'partIndex': e.attributes!.messagePart,
          },
        )
        .toList();

    final data = await SendMessageInterface.sendMultipartMessage(
      chatGuid: chat.guid,
      tempGuid: message.guid!,
      parts: parts,
      selectedMessageGuid: message.threadOriginatorGuid,
      effectId: message.expressiveSendStyleId,
      subject: message.subject,
      partIndex: _originatorPart(message),
      ddScan: needsClientSideUrlPreview && parts.any((e) => e['text'].toString().hasUrl),
    );
    return Message.fromMap(data['data']);
  }

  @override
  Future<({Message message, List<Attachment> attachments})> sendAttachment(
    Chat chat,
    Message message,
    Attachment attachment, {
    bool isAudioMessage = false,
    void Function(int count, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final data = await SendMessageInterface.sendAttachmentMessage(
      chatGuid: chat.guid,
      // The attachment carries the temp GUID for the upload — by design it is
      // the same value as the message's temp GUID (set in send_animation.dart).
      tempGuid: attachment.guid!,
      filePath: attachment.path,
      fileName: attachment.transferName!,
      fileSize: attachment.totalBytes ?? 0,
      method: _resolveMethod(message, forAttachment: true),
      selectedMessageGuid: message.threadOriginatorGuid,
      effectId: message.expressiveSendStyleId,
      subject: message.subject,
      partIndex: _originatorPart(message),
      isAudioMessage: isAudioMessage,
    );
    final attachments = ((data['data']?['attachments'] as List?) ?? <dynamic>[])
        .whereType<Map>()
        .map((e) => Attachment.fromMap(e.cast<String, Object>()))
        .toList();
    return (message: Message.fromMap(data['data']), attachments: attachments);
  }

  @override
  Future<Message> edit(Message message, String text, int partIndex) async {
    // Non-200 responses are converted to Future.error by returnSuccessOrError,
    // so reaching this line means the edit succeeded.
    final response = await HttpSvc.message.edit(message.guid!, text, "Edited to: '$text'", partIndex: partIndex);
    return Message.fromMap(response.data['data']);
  }

  @override
  Future<Message> unsend(Message message, int partIndex) async {
    final response = await HttpSvc.message.unsend(message.guid!, partIndex: partIndex);
    return Message.fromMap(response.data['data']);
  }

  // ── Chats ──────────────────────────────────────────────────────────────────

  @override
  Future<Chat> createChat(List<String> addresses, String? message, String service, {CancelToken? cancelToken}) async {
    final response = await HttpSvc.chat.create(addresses, message, service, cancelToken: cancelToken);
    return Chat.fromMap(response.data['data']);
  }

  @override
  Future<bool> renameChat(Chat chat, String newName) async {
    return (await HttpSvc.chat.setDisplayName(chat.guid, newName)).statusCode == 200;
  }

  @override
  Future<bool> chatParticipant(ParticipantOp op, Chat chat, String address) async {
    return (await HttpSvc.chat.modifyParticipant(op.name, chat.guid, address)).statusCode == 200;
  }

  @override
  Future<bool> leaveChat(Chat chat) async {
    return (await HttpSvc.chat.leave(chat.guid)).statusCode == 200;
  }

  @override
  Future<bool> markRead(Chat chat, bool notifyOthers) async {
    if (!notifyOthers) return true;
    return (await HttpSvc.chat.markRead(chat.guid)).statusCode == 200;
  }

  @override
  Future<bool> markUnread(Chat chat) async {
    return (await HttpSvc.chat.markUnread(chat.guid)).statusCode == 200;
  }

  @override
  Future<bool> setChatIcon(
    Chat chat,
    String path, {
    void Function(int count, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final response = await HttpSvc.chat.setIcon(
      chat.guid,
      path,
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );
    return response.statusCode == 200;
  }

  @override
  Future<bool> deleteChatIcon(Chat chat, {CancelToken? cancelToken}) async {
    return (await HttpSvc.chat.removeIcon(chat.guid, cancelToken: cancelToken)).statusCode == 200;
  }

  // ── Typing indicators ──────────────────────────────────────────────────────

  @override
  void startedTyping(Chat chat) {
    HttpSvc.chat.startTyping(chat.guid);
  }

  @override
  void stoppedTyping(Chat chat) {
    HttpSvc.chat.stopTyping(chat.guid);
  }

  // ── Account / handles ──────────────────────────────────────────────────────

  @override
  Future<bool?> handleiMessageState(String address) async {
    final response = await HttpSvc.handle.handleiMessageState(address);
    return response.data['data']['available'] as bool?;
  }

  @override
  Future<Map<String, dynamic>> getAccountInfo() async {
    final response = await HttpSvc.icloud.getAccountInfo();
    return (response.data['data'] as Map<String, dynamic>?) ?? {};
  }

  @override
  Future<Map<String, dynamic>> getAccountContact() async {
    if (!_server.isMinBigSur) return {};
    final response = await HttpSvc.icloud.getAccountContact();
    return (response.data['data'] as Map<String, dynamic>?) ?? {};
  }

  @override
  Future<void> setDefaultHandle(String handle) async {
    await HttpSvc.icloud.setAccountAlias(handle);
  }
}
