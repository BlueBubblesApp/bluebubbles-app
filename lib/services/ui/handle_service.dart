import 'dart:async';

import 'package:bluebubbles/app/state/handle_state.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:get_it/get_it.dart';

// ignore: non_constant_identifier_names
HandleService get HandleSvc => GetIt.I<HandleService>();

/// Centralized registry and lifecycle manager for [HandleState] objects.
///
/// ## Responsibilities
/// - Creates and caches [HandleState] per handle ID
/// - Pushes contact-sync updates into existing states
/// - Listens to redacted-mode settings and propagates redact/unredact across
///   all live states
///
/// ## Access
/// ```dart
/// final state = HandleSvc.getOrCreateHandleState(handle);
/// // or
/// final state = HandleSvc.getHandleState(handle.id!);
/// ```
///
/// ## Mutation
/// Call [updateHandleStates] from [ContactServiceV2] after a contact sync.
/// Never modify [HandleState] observables from UI code.
class HandleService {
  final tag = 'HandleService';

  /// Registry: handle ID → HandleState
  final Map<int, HandleState> _handleStates = {};

  StreamSubscription? _redactedModeListener;
  StreamSubscription? _hideContactInfoListener;
  StreamSubscription? _generateFakeAvatarsListener;
  StreamSubscription? _hideNamesForReactionsListener;

  /// Initialize the service. Call this during app startup before [ChatsService]
  /// so that [ChatState] can create handle states in its constructor.
  void init() {
    _setupRedactedModeListeners();
    Logger.info('[$tag] Initialized');
  }

  // ========== Registry ==========

  /// Returns an existing [HandleState] for [handle] or creates and caches a
  /// new one. Safe to call during [ChatState] and [MessageState] construction.
  HandleState getOrCreateHandleState(Handle handle) {
    final id = handle.id;
    if (id == null) {
      // Transient/unsaved handle — return an ephemeral state (not cached)
      return HandleState(handle);
    }
    return _handleStates.putIfAbsent(id, () => HandleState(handle));
  }

  /// Returns the cached [HandleState] for [handleId], or null if it has not
  /// been created yet.
  HandleState? getHandleState(int handleId) => _handleStates[handleId];

  // ========== Update ==========

  /// Push a batch of freshly-fetched handles (post-contact-sync) into the
  /// registry.  Existing states are updated via [HandleState.updateFromHandle];
  /// new ones are created.  Called by [ContactServiceV2.notifyHandlesUpdated].
  void updateHandleStates(List<Handle> refreshedHandles) {
    for (final handle in refreshedHandles) {
      final id = handle.id;
      if (id == null) continue;
      final existing = _handleStates[id];
      if (existing != null) {
        existing.updateFromHandle(handle);
        Logger.debug('[$tag] Updated HandleState for handle $id', tag: tag);
      } else {
        _handleStates[id] = HandleState(handle);
        Logger.debug('[$tag] Created HandleState for handle $id', tag: tag);
      }
    }
  }

  // ========== Redacted Mode ==========

  void _setupRedactedModeListeners() {
    _redactedModeListener = SettingsSvc.settings.redactedMode.listen((enabled) {
      for (final state in _handleStates.values) {
        if (enabled) {
          state.redactFields();
        } else {
          state.unredactFields();
        }
      }
    });

    _hideContactInfoListener = SettingsSvc.settings.hideContactInfo.listen((enabled) {
      for (final state in _handleStates.values) {
        if (enabled) {
          state.redactContactInfo();
        } else {
          state.unredactContactInfo();
        }
      }
    });

    _generateFakeAvatarsListener = SettingsSvc.settings.generateFakeAvatars.listen((enabled) {
      for (final state in _handleStates.values) {
        if (enabled) {
          state.redactAvatars();
        } else {
          state.unredactAvatars();
        }
      }
    });

    _hideNamesForReactionsListener = SettingsSvc.settings.hideNamesForReactions.listen((hide) {
      for (final state in _handleStates.values) {
        if (hide) {
          state.hideReactionName();
        } else {
          state.showReactionName();
        }
      }
    });
  }

  /// Clears cached [HandleState]s without tearing down the service's
  /// listeners (redacted mode, contact info, fake avatars, reaction names).
  /// Use this for a data reset where the service stays alive for the rest of
  /// the app session. Contrast with [close], which fully tears down the
  /// service at app shutdown.
  void reset() {
    _handleStates.clear();
  }

  void close() {
    _redactedModeListener?.cancel();
    _hideContactInfoListener?.cancel();
    _generateFakeAvatarsListener?.cancel();
    _hideNamesForReactionsListener?.cancel();
    _handleStates.clear();
  }
}
