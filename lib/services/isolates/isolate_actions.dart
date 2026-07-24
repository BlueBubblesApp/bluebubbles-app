import 'package:bluebubbles/services/backend/actions/app_actions.dart';
import 'package:bluebubbles/services/backend/actions/attachment_actions.dart';
import 'package:bluebubbles/services/backend/actions/log_actions.dart';
import 'package:bluebubbles/services/backend/actions/send_message_actions.dart';
import 'package:bluebubbles/services/backend/actions/chat_actions.dart';
import 'package:bluebubbles/services/backend/actions/contact_v2_actions.dart';
import 'package:bluebubbles/services/backend/actions/custom_group_actions.dart';
import 'package:bluebubbles/services/backend/actions/handle_actions.dart';
import 'package:bluebubbles/services/backend/actions/image_actions.dart';
import 'package:bluebubbles/services/backend/actions/message_actions.dart';
import 'package:bluebubbles/services/backend/actions/prefs_actions.dart';
import 'package:bluebubbles/services/backend/actions/server_actions.dart';
import 'package:bluebubbles/services/backend/actions/sync_actions.dart';
import 'package:bluebubbles/services/backend/actions/test_actions.dart';
import 'package:bluebubbles/services/isolates/global_isolate.dart';
import 'package:bluebubbles/services/network/http_service.dart';

class IsolateActons {
  static final Map<IsolateRequestType, IsolateAction> actions = {
    // Testing — sync and/or fixed-type params, so wrap as async lambdas.
    // NOTE: Sync functions and no-arg functions MUST be wrapped as async lambdas
    // because IsolateAction = Future<dynamic> Function(dynamic).
    // Async Future<void>/Future<T> functions can be referenced directly.
    IsolateRequestType.testReturnInput: (data) async => TestActions.executeTestReturnInput(data as String),
    IsolateRequestType.testPrintInput: (data) async {
      TestActions.executeTestPrintInput(data as String);
    },
    IsolateRequestType.testThrowError: (data) async {
      TestActions.executeTestThrowError(data as String);
    },

    // App — no-arg, wrap to accept and ignore the data param
    IsolateRequestType.checkForUpdate: (_) => AppActions.checkForUpdate(),

    // Server — no-arg, wrap to accept and ignore the data param
    IsolateRequestType.checkForServerUpdate: (_) => ServerActions.checkForServerUpdate(),
    IsolateRequestType.getServerDetails: (_) => ServerActions.getServerDetails(),

    // Image — convertToPng is sync so wrap as async lambda
    IsolateRequestType.convertImageToPng: (data) async => ImageActions.convertToPng(data as Map<String, dynamic>),
    IsolateRequestType.readExifData: ImageActions.readExifData,
    IsolateRequestType.getGifDimensions: ImageActions.getGifDimensions,

    // Prefs
    IsolateRequestType.saveReplyToMessageState: PrefsActions.saveReplyToMessageState,
    IsolateRequestType.loadReplyToMessageState: PrefsActions.loadReplyToMessageState,
    IsolateRequestType.syncAllSettings: PrefsActions.syncAllSettings,
    IsolateRequestType.syncSettings: PrefsActions.syncSettings,

    // Messages — getMessages is no-arg, wrap to accept and ignore the data param
    IsolateRequestType.getMessages: (_) => MessageActions.getMessages(),
    IsolateRequestType.replaceMessage: MessageActions.replaceMessage,
    IsolateRequestType.deleteMessage: MessageActions.deleteMessage,
    IsolateRequestType.softDeleteMessage: MessageActions.softDeleteMessage,
    IsolateRequestType.fetchAssociatedMessagesAsync: MessageActions.fetchAssociatedMessagesAsync,
    IsolateRequestType.saveMessageAsync: MessageActions.saveMessageAsync,
    IsolateRequestType.findOneAsync: MessageActions.findOneAsync,
    IsolateRequestType.findAsync: MessageActions.findAsync,

    // Chat
    IsolateRequestType.clearNotificationForChat: ChatActions.clearNotificationForChat,
    IsolateRequestType.markAllChatsRead: ChatActions.markAllChatsRead,
    IsolateRequestType.markChatReadUnread: ChatActions.markChatReadUnread,
    IsolateRequestType.startTyping: ChatActions.startTyping,
    IsolateRequestType.stopTyping: ChatActions.stopTyping,
    IsolateRequestType.saveChat: ChatActions.saveChat,
    IsolateRequestType.deleteChat: ChatActions.deleteChat,
    IsolateRequestType.softDeleteChat: ChatActions.softDeleteChat,
    IsolateRequestType.unDeleteChat: ChatActions.unDeleteChat,
    IsolateRequestType.addMessageToChat: ChatActions.addMessageToChat,
    IsolateRequestType.loadSupplementalData: ChatActions.loadSupplementalData,
    IsolateRequestType.syncLatestMessages: ChatActions.syncLatestMessages,
    IsolateRequestType.bulkSyncChats: ChatActions.bulkSyncChats,
    IsolateRequestType.getMessagesAsync: ChatActions.getMessagesAsync,
    IsolateRequestType.getParticipantsAsync: ChatActions.getParticipantsAsync,
    IsolateRequestType.clearTranscriptAsync: ChatActions.clearTranscriptAsync,
    IsolateRequestType.getChatsAsync: ChatActions.getChatsAsync,

    // Handle
    IsolateRequestType.saveHandleAsync: HandleActions.saveHandleAsync,
    IsolateRequestType.bulkSaveHandlesAsync: HandleActions.bulkSaveHandlesAsync,
    IsolateRequestType.findOneHandleAsync: HandleActions.findOneHandleAsync,
    IsolateRequestType.findHandlesAsync: HandleActions.findHandlesAsync,

    // ContactV2 (new contact service)
    IsolateRequestType.syncContactsToHandles: ContactV2Actions.syncContactsToHandles,
    IsolateRequestType.getStoredContactIds: ContactV2Actions.getStoredContactIds,
    IsolateRequestType.findOneContact: ContactV2Actions.findOneContact,
    IsolateRequestType.getContactsForHandles: ContactV2Actions.getContactsForHandles,
    IsolateRequestType.getContactByAddress: ContactV2Actions.getContactByAddress,
    IsolateRequestType.getAllContacts: ContactV2Actions.getAllContacts,
    IsolateRequestType.getContactAvatar: ContactV2Actions.getContactAvatar,
    IsolateRequestType.uploadContactsV2: ContactV2Actions.uploadContacts,

    // Attachment
    IsolateRequestType.saveAttachmentAsync: AttachmentActions.saveAttachmentAsync,
    IsolateRequestType.bulkSaveAttachmentsAsync: AttachmentActions.bulkSaveAttachmentsAsync,
    IsolateRequestType.replaceAttachmentAsync: AttachmentActions.replaceAttachmentAsync,
    IsolateRequestType.findOneAttachmentAsync: AttachmentActions.findOneAttachmentAsync,
    IsolateRequestType.findAttachmentsAsync: AttachmentActions.findAttachmentsAsync,
    IsolateRequestType.deleteAttachmentAsync: AttachmentActions.deleteAttachmentAsync,

    // Network
    IsolateRequestType.setOriginOverride: (data) async {
      HttpSvc.originOverride = data as String?;
    },

    // Sync
    IsolateRequestType.performIncrementalSync: SyncActions.performIncrementalSync,
    IsolateRequestType.bulkSyncData: SyncActions.bulkSyncData,

    // Log actions
    IsolateRequestType.getLogs: (data) => LogActions.getLogs(data as Map<String, dynamic>),

    // Send message (routed through isolate so sends survive backgrounding)
    IsolateRequestType.sendTextMessage: SendMessageActions.sendTextMessage,
    IsolateRequestType.sendTapback: SendMessageActions.sendTapback,
    IsolateRequestType.sendMultipartMessage: SendMessageActions.sendMultipartMessage,
    IsolateRequestType.sendAttachmentMessage: SendMessageActions.sendAttachmentMessage,

    // CustomGroup
    IsolateRequestType.getAllCustomGroups: CustomGroupActions.getAllIds,
    IsolateRequestType.createCustomGroup: CustomGroupActions.create,
    IsolateRequestType.renameCustomGroup: CustomGroupActions.rename,
    IsolateRequestType.updateCustomGroupChats: CustomGroupActions.updateChats,
    IsolateRequestType.setCustomGroupShowUnreadBadge: CustomGroupActions.setShowUnreadBadge,
    IsolateRequestType.deleteCustomGroup: CustomGroupActions.delete,
    IsolateRequestType.reorderCustomGroups: CustomGroupActions.reorder,
  };
}
