import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/network/http_service.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

/// Get an instance of the active [BackendService]
// ignore: non_constant_identifier_names
BackendService get BackendSvc => GetIt.I<BackendService>();

/// Which side of a participant change is being applied.
enum ParticipantOp { add, remove }

/// The seam between the app and whatever actually delivers iMessages.
///
/// Everything above this interface — UI, state services, the outgoing queue —
/// talks in terms of [Chat]/[Message]/[Attachment] and *capabilities*, never in
/// terms of a BlueBubbles server, its REST shape, or its macOS version. The
/// stock implementation is [BlueBubblesBackend], which forwards to `HttpSvc`.
///
/// Two rules keep this interface useful:
///
/// 1. **Return domain objects, not transport payloads.** Methods return
///    [Message], not the raw `Map` a particular server happened to send back.
/// 2. **Gate features on capability getters, not on server facts.** UI asks
///    `BackendSvc.canEditUnsend`, never `serverVersionCode >= 148 && isMinVentura`.
///    A capability answers "can this backend do X", and each implementation
///    decides how it knows.
abstract class BackendService {
  /// Called once during startup, after the service is registered.
  Future<void> init();

  // ── Capabilities ───────────────────────────────────────────────────────────
  // Semantic feature checks. The stock implementation derives these from the
  // connected server's version and macOS version; another backend may hardcode
  // them or compute them some other way.

  /// Edit and undo-send already-sent messages.
  bool get canEditUnsend;

  /// Schedule a message to be sent later.
  bool get canSchedule;

  /// Attach a subject line to an outgoing message.
  bool get canSendSubject;

  /// Leave a group chat.
  bool get canLeaveChat;

  /// Create brand-new group chats.
  bool get canCreateGroupChats;

  /// Rename a group and set/remove its icon.
  bool get canManageGroupChat;

  /// Cancel an in-flight attachment upload.
  bool get canCancelUploads;

  /// Read focus/Do-Not-Disturb state for a handle.
  bool get supportsFocusStates;

  /// Find My friends and devices.
  bool get supportsFindMy;

  /// Forward SMS/RCS through a connected phone.
  bool get supportsSmsForwarding;

  /// Send messages with expressive effects, mentions, and rich formatting.
  bool get supportsRichSend;

  /// Whether the *client* must scan outgoing text for links to build a preview.
  /// When false the backend generates link previews itself.
  bool get needsClientSideUrlPreview;

  /// Delete a message/chat outright rather than moving it to a recycle bin.
  bool get canHardDelete;

  /// The underlying [HttpService], or null when this backend does not talk to
  /// a BlueBubbles server at all. This is an escape hatch for server-management
  /// UI (logs, stats, restart, backups) that is inherently BlueBubbles-specific
  /// — it must not be used to implement messaging behaviour.
  HttpService? get remoteService;

  // ── Sending ────────────────────────────────────────────────────────────────
  // These return the backend-confirmed [Message], which the outgoing pipeline
  // reconciles against the temporary local record.

  /// Sends a plain text message.
  Future<Message> sendText(Chat chat, Message message, {CancelToken? cancelToken});

  /// Sends a reaction/tapback against [selected].
  Future<Message> sendTapback(
    Chat chat,
    Message message,
    Message selected,
    String reaction, {
    CancelToken? cancelToken,
  });

  /// Sends a multipart message (mentions / mixed rich content).
  Future<Message> sendMultipart(Chat chat, Message message, {CancelToken? cancelToken});

  /// Sends [attachment] as a message.
  ///
  /// Returns both the confirmed message and the confirmed attachments. They are
  /// kept separate because the outgoing pipeline reconciles attachment GUIDs
  /// before it reconciles the message GUID, and [Message] itself carries
  /// attachments only once it has been persisted.
  Future<({Message message, List<Attachment> attachments})> sendAttachment(
    Chat chat,
    Message message,
    Attachment attachment, {
    bool isAudioMessage = false,
    void Function(int count, int total)? onSendProgress,
    CancelToken? cancelToken,
  });

  /// Edits a previously sent message part, returning the updated message.
  /// Throws if the backend rejected the edit.
  Future<Message> edit(Message message, String text, int partIndex);

  /// Undo-sends a message part, returning the updated message.
  /// Throws if the backend rejected the unsend.
  Future<Message> unsend(Message message, int partIndex);

  // ── Chats ──────────────────────────────────────────────────────────────────

  /// Creates a chat with [addresses], optionally sending [message] immediately.
  Future<Chat> createChat(List<String> addresses, String? message, String service, {CancelToken? cancelToken});

  /// Renames a group chat.
  Future<bool> renameChat(Chat chat, String newName);

  /// Adds or removes a participant.
  Future<bool> chatParticipant(ParticipantOp op, Chat chat, String address);

  /// Leaves a group chat.
  Future<bool> leaveChat(Chat chat);

  /// Marks a chat read. [notifyOthers] controls whether a read receipt is sent.
  Future<bool> markRead(Chat chat, bool notifyOthers);

  /// Marks a chat unread locally.
  Future<bool> markUnread(Chat chat);

  /// Sets the group icon from the file at [path].
  Future<bool> setChatIcon(
    Chat chat,
    String path, {
    void Function(int count, int total)? onSendProgress,
    CancelToken? cancelToken,
  });

  /// Removes the group icon.
  Future<bool> deleteChatIcon(Chat chat, {CancelToken? cancelToken});

  // ── Typing indicators ──────────────────────────────────────────────────────

  void startedTyping(Chat chat);

  void stoppedTyping(Chat chat);

  // NOTE: attachment *downloading* is deliberately not part of this interface
  // yet. It is owned by AttachmentDownloadService/AttachmentDownloadController,
  // which carry their own reactive progress and caching model; abstracting that
  // subsystem is a follow-up rather than something to half-do here.

  // ── Account / handles ──────────────────────────────────────────────────────

  /// Whether [address] is reachable over iMessage, or null if the backend
  /// could not determine it.
  Future<bool?> handleiMessageState(String address);

  /// Details about the signed-in account (aliases, active alias, ...).
  Future<Map<String, dynamic>> getAccountInfo();

  /// The signed-in account's own contact card, when available.
  Future<Map<String, dynamic>> getAccountContact();

  /// Sets the outgoing alias/handle messages are sent from.
  Future<void> setDefaultHandle(String handle);
}
