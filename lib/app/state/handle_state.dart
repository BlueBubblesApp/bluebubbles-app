import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:faker/faker.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// State wrapper for [Handle] that provides granular reactivity for UI components.
///
/// Each field that may affect the UI is tracked separately, allowing widgets
/// to observe only the specific properties they care about via [Obx()].
///
/// ## Ownership
/// [HandleState] instances are owned by [HandleService] and stored in a
/// per-handle registry keyed by [Handle.id]. Access them via
/// [HandleService.getOrCreateHandleState] — never construct directly outside
/// of [HandleService].
///
/// ## Mutation rules
/// Only call [*Internal()] methods from [HandleService]. UI code must never
/// write to these observables directly. Color updates go through
/// [Handle.saveAsync] followed by [ContactServiceV2.notifyHandlesUpdated].
///
/// ## Redaction
/// Redacted-mode logic (fake names, hidden contact info, fake avatars) lives
/// entirely in [HandleState]. The [Handle] DB object returns raw data only.
/// [HandleService] drives redaction in response to settings changes.
class HandleState {
  /// Reference to the underlying DB object.
  /// Replaced (non-final) by [updateFromHandle] so post-sync contact data is
  /// always fresh for subsequent calls such as [unredactAvatars].
  Handle handle;

  // ── Reactive fields --------------------------------------------------------

  /// Display name suitable for UI labels (conversation list, message sender).
  /// Reflects redacted mode when active.
  final RxnString displayName;

  /// Display name for reaction notifications ("John liked…").
  /// May differ from [displayName] (first name only for groups).
  /// Reflects redacted mode when active.
  final RxnString reactionDisplayName;

  /// Avatar initials (1–2 characters). Null for business chats.
  final RxnString initials;

  /// Local file path to the contact's avatar image, if available.
  /// Null when no avatar is set or when [generateFakeAvatars] is active.
  final RxnString avatarPath;

  /// Hex-string color override for avatar gradient and colorful bubbles.
  /// Null means the default address-derived gradient is used.
  final RxnString color;

  /// Default email address for outgoing emails (may differ from [handle.address]).
  final RxnString defaultEmail;

  /// Default phone number for outgoing calls/SMS.
  final RxnString defaultPhone;

  /// Human-readable formatted address (e.g. "+1 (555) 867-5309").
  /// Falls back to [handle.address] when not formatted.
  final RxnString formattedAddress;

  /// Fake name generated once at construction and reused every time redacted
  /// mode is toggled, so the displayed name stays consistent.
  final String fakeName;

  final String fakeAddress;

  HandleState(this.handle)
      : displayName = RxnString(handle.displayName),
        reactionDisplayName = RxnString(handle.reactionDisplayName),
        initials = RxnString(handle.initials),
        avatarPath = RxnString(_resolveAvatarPath(handle)),
        color = RxnString(handle.color),
        defaultEmail = RxnString(handle.defaultEmail),
        defaultPhone = RxnString(handle.defaultPhone),
        formattedAddress = RxnString(handle.formattedAddress ?? handle.address),
        fakeName = faker.person.name(),
        fakeAddress = formatPhoneNumber(faker.phoneNumber.us().split('x').first.trim()) {
    if (SettingsSvc.settings.redactedMode.value) {
      redactFields();
    }
    _recomputeReactionDisplayName();
  }

  // ========== Pure Compute Helpers ==========
  // These operate on raw handle data only — no redaction logic.

  static String? _resolveAvatarPath(Handle h) {
    if (kIsWeb) return null;
    // The server can return the same person twice (Contacts record and chat.db card), only one with a photo.
    return h.contactsV2.map((c) => c.avatarPath).nonNulls.firstOrNull;
  }

  // ========== Internal State Update Methods ==========
  // Called by HandleService only — do NOT call from UI code.

  /// Refresh all reactive fields from a re-fetched [Handle] after a contact sync.
  void updateFromHandle(Handle refreshed) {
    // Merge scalar overrides that may have been written locally (e.g. custom
    // avatar color) into the refreshed object before we adopt it.
    refreshed.formattedAddress ??= handle.formattedAddress;
    refreshed.defaultEmail ??= handle.defaultEmail;
    refreshed.defaultPhone ??= handle.defaultPhone;
    refreshed.color ??= handle.color;

    // Replace the stored reference so that all future compute calls
    // (including unredactAvatars, unredactContactInfo, etc.) operate on the
    // freshly-fetched handle whose contactsV2 ToMany lazily re-queries the DB.
    handle = refreshed;

    updateDisplayNameInternal(handle.displayName);
    _recomputeReactionDisplayName();
    updateInitialsInternal(handle.initials);
    updateAvatarPathInternal(_resolveAvatarPath(handle));
    updateColorInternal(handle.color);
    updateDefaultEmailInternal(handle.defaultEmail);
    updateDefaultPhoneInternal(handle.defaultPhone);
    updateFormattedAddressInternal(handle.formattedAddress ?? handle.address);

    // Re-apply redaction over the fresh values if redacted mode is active
    if (SettingsSvc.settings.redactedMode.value) {
      redactFields();
    }
  }

  void updateDisplayNameInternal(String? value) {
    if (displayName.value != value) displayName.value = value;
  }

  void updateReactionDisplayNameInternal(String? value) {
    if (reactionDisplayName.value != value) reactionDisplayName.value = value;
  }

  void updateInitialsInternal(String? value) {
    if (initials.value != value) initials.value = value;
  }

  void updateAvatarPathInternal(String? value) {
    if (avatarPath.value != value) avatarPath.value = value;
  }

  void updateColorInternal(String? value) {
    if (color.value != value) color.value = value;
  }

  void updateDefaultEmailInternal(String? value) {
    if (defaultEmail.value != value) defaultEmail.value = value;
  }

  void updateDefaultPhoneInternal(String? value) {
    if (defaultPhone.value != value) defaultPhone.value = value;
  }

  void updateFormattedAddressInternal(String? value) {
    if (formattedAddress.value != value) formattedAddress.value = value;
  }

  // ========== Redaction Methods ==========
  // Called by HandleService when redacted mode settings change.

  /// Apply all redactions based on current settings.
  void redactFields() {
    if (!SettingsSvc.settings.redactedMode.value) return;
    redactContactInfo();
    redactAvatars();
  }

  /// Remove all redactions (called when redacted mode is disabled).
  void unredactFields() {
    unredactContactInfo();
    unredactAvatars();
  }

  /// Redact display names: sets fake name or empty string per settings.
  void redactContactInfo() {
    if (!SettingsSvc.settings.redactedMode.value) return;
    if (!SettingsSvc.settings.hideContactInfo.value) return;

    updateDisplayNameInternal(fakeName);
    _recomputeReactionDisplayName();
    updateInitialsInternal(null);
    updateFormattedAddressInternal(fakeAddress);
  }

  /// Restore contact info to real values.
  void unredactContactInfo() {
    updateDisplayNameInternal(handle.displayName);
    _recomputeReactionDisplayName();
    updateInitialsInternal(handle.initials);
    updateFormattedAddressInternal(handle.formattedAddress ?? handle.address);
  }

  /// Redact avatar: clears avatarPath so the widget falls back to a placeholder.
  void redactAvatars() {
    if (!SettingsSvc.settings.redactedMode.value) return;
    if (!SettingsSvc.settings.generateFakeAvatars.value) return;
    updateAvatarPathInternal(null);
  }

  /// Restore avatar to the real value.
  void unredactAvatars() {
    updateAvatarPathInternal(_resolveAvatarPath(handle));
  }

  // ========== Reaction Name Visibility ==========
  // Called by HandleService when [Settings.hideNamesForReactions] changes.

  /// Computes the correct [reactionDisplayName] value based on all active
  /// settings, always reflecting the latest priority order:
  /// hideNamesForReactions > redactedMode (fake names) > redactedMode (hide) > real name.
  void _recomputeReactionDisplayName() {
    if (SettingsSvc.settings.hideNamesForReactions.value) {
      updateReactionDisplayNameInternal(null);
    } else if (SettingsSvc.settings.redactedMode.value && SettingsSvc.settings.hideContactInfo.value) {
      updateReactionDisplayNameInternal(fakeName);
    } else {
      updateReactionDisplayNameInternal(handle.reactionDisplayName);
    }
  }

  /// Hides the reaction sender name (called by [HandleService] when
  /// [Settings.hideNamesForReactions] is toggled on).
  void hideReactionName() => _recomputeReactionDisplayName();

  /// Restores the reaction sender name (called by [HandleService] when
  /// [Settings.hideNamesForReactions] is toggled off).
  void showReactionName() => _recomputeReactionDisplayName();
}
