import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/material.dart';

/// Mixin for initializing and managing MessagesService with proper message controllers and states.
/// This ensures MessageHolder widgets have access to MessageState observables for reactivity.
///
/// Usage:
/// 1. Apply this mixin to your State class
/// 2. Call initializeMessagesService() in initState with your messages
/// 3. For async loading scenarios, manually orchestrate loading and then call initializeMessagesService()
/// 4. Call disposeMessagesService() in dispose
/// 5. Access via the messageService getter
mixin MessagesServiceMixin<T extends StatefulWidget> on State<T> {
  MessagesService? _messageService;

  /// Get the messages service instance
  MessagesService get messageService {
    assert(_messageService != null, 'MessagesService not initialized. Call initialize method first.');
    return _messageService!;
  }

  /// Check if the service has been initialized
  bool get isMessagesServiceInitialized => _messageService != null;

  /// Initialize the messages service with a pre-loaded list of messages.
  /// Use this for simple cases like peek views or dialogs where messages are already loaded.
  ///
  /// Parameters:
  /// - chat: The chat for this messages service
  /// - messages: Initial list of messages to add to struct and create controllers for
  /// - cvController: The conversation view controller to link to each message controller
  /// - customService: Optional custom MessagesService instance (for testing or special cases)
  /// - onNewMessage: Handler for new messages (optional, defaults to no-op)
  /// - onUpdatedMessage: Handler for updated messages (optional, defaults to no-op)
  /// - onDeletedMessage: Handler for deleted messages (optional, defaults to no-op)
  /// - onJumpToMessage: Handler for jump to message requests (optional, defaults to no-op)
  void initializeMessagesService(
    Chat chat,
    List<Message> messages,
    ConversationViewController cvController, {
    MessagesService? customService,
    void Function(Message)? onNewMessage,
    void Function(Message, {String? oldGuid})? onUpdatedMessage,
    void Function(Message)? onDeletedMessage,
    void Function(String)? onJumpToMessage,
    List<Message>? messagesRef,
  }) {
    // Use custom service or get/create singleton
    _messageService = customService != null ? registerMessagesSvc(customService) : ensureMessagesSvc(chat.guid);

    // Take ownership: if another view for this chat is still mounted (duplicate
    // ConversationView), its dispose must leave the service alone from now on.
    _messageService!.owner = this;

    // Only initialize handlers if this is NOT a customService
    // CustomService is already initialized by the caller, don't reinitialize
    // to avoid triggering Get.reload() which deletes and recreates the service
    if (customService == null) {
      _messageService!.init(
        chat,
        onNewMessage ?? (_) {},
        onUpdatedMessage ?? (_, {String? oldGuid}) {},
        onDeletedMessage ?? (_) {},
        onJumpToMessage ?? (_) {},
        messagesRef ?? messages,
      );
    } else {
      // For customService, just update the handlers without reinitializing,
      // but always ensure chat is set (may not be if caller skipped init).
      _messageService!.chat = chat;
      _messageService!.updateFunc = onUpdatedMessage ?? (_, {String? oldGuid}) {};
      _messageService!.removeFunc = onDeletedMessage ?? (_) {};
      _messageService!.newFunc = onNewMessage ?? (_) {};
      _messageService!.jumpToMessage = onJumpToMessage ?? (_) {};
      _messageService!.messagesRef = messagesRef ?? messages;
    }

    // Add messages to struct (required for MessageState creation)
    final messagesToAdd =
        messages.where((m) => m.guid != null && _messageService!.struct.getMessage(m.guid!) == null).toList();
    if (messagesToAdd.isNotEmpty) {
      _messageService!.struct.addMessages(messagesToAdd);
    }

    // Ensure MessageStates exist for all messages (created on-demand via getMessageState)
    for (final message in messages) {
      if (message.guid != null) {
        _messageService!.getOrCreateMessageState(message.guid!);
      }
    }

    // Create controllers and link them
    _createControllers(messages, cvController);
  }

  /// Helper method to create and link controllers for a list of messages
  void _createControllers(List<Message> messages, ConversationViewController cvController) {
    for (final message in messages) {
      if (message.guid != null) {
        final controller = _messageService!.getOrCreateState(message);
        controller.cvController = cvController;
      }
    }
  }

  /// Load the next chunk of messages (for pagination)
  /// Returns true if more messages are available, false if no more messages
  Future<bool> loadNextChunk(
    ConversationViewController cvController,
    List<Message> currentMessages, {
    int limit = 25,
  }) async {
    assert(_messageService != null, 'MessagesService not initialized');

    // Load the next chunk using the service
    final hasMore = await _messageService!.loadChunk(
      currentMessages.length,
      cvController,
      limit: limit,
    );

    return hasMore;
  }

  /// Load a search chunk around a specific message
  Future<void> loadSearchChunk(Message message, SearchMethod method) async {
    assert(_messageService != null, 'MessagesService not initialized');
    await _messageService!.loadSearchChunk(message, method);
  }

  /// Reload the entire messages service (clears and reinitializes)
  Future<void> reloadMessagesService(
    Chat chat,
    ConversationViewController cvController, {
    required void Function(Message) onNewMessage,
    required void Function(Message, {String? oldGuid}) onUpdatedMessage,
    required void Function(Message) onDeletedMessage,
    required void Function(String) onJumpToMessage,
    required List<Message> messages,
  }) async {
    assert(_messageService != null, 'MessagesService not initialized');

    _messageService!.reload();
    _messageService!.init(chat, onNewMessage, onUpdatedMessage, onDeletedMessage, onJumpToMessage, messages);
  }

  /// Create and link a state for a new message
  /// Use this when handling new messages that aren't in the existing list
  /// Returns the created state
  MessageState createStateForMessage(
    Message message,
    ConversationViewController cvController,
  ) {
    assert(_messageService != null, 'MessagesService not initialized');

    final controller = _messageService!.getOrCreateState(message);
    controller.cvController = cvController;
    return controller;
  }

  /// Create and link states for multiple new messages
  /// Use this when handling bulk message additions
  void createStatesForMessages(
    List<Message> messages,
    ConversationViewController cvController,
  ) {
    assert(_messageService != null, 'MessagesService not initialized');
    _createControllers(messages, cvController);
  }

  /// Dispose the messages service and clean up resources.
  ///
  /// Set [onlyDetach] to true to clear the mixin's local reference without
  /// calling [MessagesService.close]. Use this when the service is being
  /// "transferred" to another widget (e.g. a customService passed from
  /// ChatCreator to ConversationView) so the service stays alive in GetX's
  /// registry and [prepMessage] can still reach it via [addNewMessage].
  void disposeMessagesService({bool force = false, bool onlyDetach = false}) {
    if (!onlyDetach) {
      if (_messageService != null && _messageService!.owner != null && _messageService!.owner != this) {
        // A newer view for the same chat took ownership (duplicate ConversationView,
        // e.g. via notification tap) — deleting the shared tagged service here would
        // crash the successor's MessageHolders with "not registered".
        Logger.debug('Skipping MessagesService close for ${_messageService!.tag} — owned by a newer view',
            tag: 'MessagesServiceMixin');
      } else {
        _messageService?.close(force: force);
        if (_messageService?.owner == this) _messageService?.owner = null;
      }
    }

    _messageService = null;
  }
}
