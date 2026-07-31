import 'dart:async';
import 'dart:convert';

import 'package:async_task/async_task_extension.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/details_menu_action.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/buttons/text_field_button.dart';
import 'package:bluebubbles/env.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/backend/interfaces/prefs_interface.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart' show Level;
import 'package:universal_io/io.dart';

class Settings {
  final RxString iMessageStatsSource = "server".obs;
  final RxInt firstFcmRegisterDate = 0.obs;
  final RxString iCloudAccount = "".obs;
  final RxString guidAuthKey = "".obs;
  final RxString serverAddress = "".obs;
  final Rx<Map<String, String>> customHeaders = Rx<Map<String, String>>(<String, String>{});
  final RxBool finishedSetup = false.obs;
  final RxBool reachedConversationList = false.obs;
  final RxBool autoDownload = true.obs;
  final RxBool onlyWifiDownload = false.obs;
  final RxInt maxConcurrentDownloads = 2.obs;
  final RxBool autoSave = false.obs;
  final RxString autoSavePicsLocation = "Pictures".obs;
  final RxString autoSaveDocsLocation = FilesystemService.androidDownloadsPath.obs;
  final RxDouble previewImageQuality = 0.75.obs; // 0.25 to 1.0
  final RxBool autoOpenKeyboard = true.obs;
  final RxBool hideTextPreviews = false.obs;
  final RxBool showIncrementalSync = false.obs;
  final RxBool highPerfMode = false.obs;
  final RxBool reduceMotion = false.obs;
  final RxInt lastIncrementalSync = 0.obs;
  final RxInt lastIncrementalSyncRowId = 0.obs;
  final RxInt refreshRate = 0.obs;
  final RxBool colorfulAvatars = false.obs;
  final RxBool colorfulBubbles = false.obs;
  final RxBool hideDividers = false.obs;
  final RxDouble scrollVelocity = 1.00.obs;
  final RxBool sendWithReturn = false.obs;
  final RxBool doubleTapForDetails = false.obs;
  final RxBool denseChatTiles = false.obs;
  final RxBool smartReply = false.obs;
  final RxBool showSyncIndicator = true.obs;
  final RxInt sendDelay = 0.obs;
  final RxBool recipientAsPlaceholder = false.obs;
  final RxBool hideKeyboardOnScroll = false.obs;
  final RxBool moveChatCreatorToHeader = false.obs;
  final RxBool showFiltersInHeader = false.obs;
  final RxBool showCustomGroupFilterChips = false.obs;
  final RxBool cameraFAB = false.obs;
  final RxBool swipeToCloseKeyboard = false.obs;
  final RxBool swipeToOpenKeyboard = false.obs;
  final RxBool openKeyboardOnSTB = false.obs;
  final RxBool swipableConversationTiles = false.obs;
  final RxBool showDeliveryTimestamps = false.obs;
  final RxBool filteredChatList = false.obs;
  final RxBool startVideosMuted = true.obs;
  final RxBool startVideosMutedFullscreen = true.obs;
  final RxBool use24HrFormat = false.obs;
  final RxBool alwaysShowAvatars = false.obs;
  final RxBool notifyOnChatList = false.obs;
  final RxBool notifyReactions = true.obs;
  final RxBool colorsFromMedia = false.obs;
  final RxString globalTextDetection = "".obs;
  final RxBool filterUnknownSenders = false.obs;
  /// Dimension name -> enum name (e.g. `{"read": "unread", "type": "group"}`).
  final Rx<Map<String, String>> savedChatFilters = Rx<Map<String, String>>(<String, String>{});
  final RxBool tabletMode = true.obs;
  final RxBool highlightSelectedChat = true.obs;
  final RxBool immersiveMode = true.obs;
  final RxDouble avatarScale = 1.0.obs;
  final RxBool askWhereToSave = false.obs;
  final RxBool statusIndicatorsOnChats = false.obs;
  final RxInt apiTimeout = 30000.obs;
  final RxBool allowUpsideDownRotation = false.obs;
  final RxBool cancelQueuedMessages = false.obs;
  final RxBool repliesToPrevious = false.obs;
  final RxnString localhostPort = RxnString(null);
  final RxBool useLocalIpv6 = false.obs;
  final RxnString sendSoundPath = RxnString();
  final RxnString receiveSoundPath = RxnString();
  final RxInt soundVolume = 100.obs;
  final RxBool syncContactsAutomatically = false.obs;
  final RxBool scrollToBottomOnSend = true.obs;
  final RxBool sendEventsToTasker = false.obs;
  final RxBool keepAppAlive = false.obs;
  final RxBool unarchiveOnNewMessage = false.obs;
  final RxBool scrollToLastUnread = false.obs;
  final RxString userName = "You".obs;
  final RxnString userAvatarPath = RxnString();
  final RxBool hideNamesForReactions = false.obs;
  final RxBool replaceEmoticonsWithEmoji = false.obs;

  // final RxString emojiFontFamily;

  // Private API features
  final RxnBool serverPrivateAPI = RxnBool();
  final RxBool enablePrivateAPI = false.obs;
  final RxBool privateSendTypingIndicators = false.obs;
  final RxBool privateMarkChatAsRead = false.obs;
  final RxBool privateManualMarkAsRead = false.obs;
  final RxBool privateSubjectLine = false.obs;
  final RxBool privateAPISend = false.obs;
  final RxBool privateAPIAttachmentSend = false.obs;
  final RxBool editLastSentMessageOnUpArrow = false.obs;
  final RxInt lastReviewRequestTimestamp = 0.obs;

  // Redacted Mode Settings
  final RxBool redactedMode = false.obs;
  final RxBool hideAttachments = true.obs;
  final RxBool hideContactInfo = true.obs;
  final RxBool generateFakeAvatars = false.obs;
  final RxBool hideMessageContent = false.obs;

  // Unified Push Settings
  final RxBool enableUnifiedPush = false.obs;
  final RxString endpointUnifiedPush = RxString("");

  // Quick tapback settings
  final RxBool enableQuickTapback = false.obs;
  final RxString quickTapbackType = ReactionTypes.toList()[0].obs; // The 'love' reaction

  // Notification reaction settings
  final RxBool notificationReactionAction = true.obs;
  final RxString notificationReactionActionType = ReactionTypes.LIKE.obs; // Default to 'like'

  // Slideable action settings
  final Rx<MaterialSwipeAction> materialRightAction = MaterialSwipeAction.pin.obs;
  final Rx<MaterialSwipeAction> materialLeftAction = MaterialSwipeAction.archive.obs;

  // Security settings
  final RxBool shouldSecure = RxBool(false);
  final Rx<SecurityLevel> securityLevel = Rx<SecurityLevel>(SecurityLevel.locked);
  final RxBool incognitoKeyboard = RxBool(false);

  final Rx<Skins> skin = Skins.iOS.obs;
  final Rx<ThemeMode> theme = ThemeMode.system.obs;
  final Rx<SwipeDirection> fullscreenViewerSwipeDir = SwipeDirection.RIGHT.obs;

  // Pin settings
  final RxInt pinRowsPortrait = RxInt(3);
  final RxInt pinColumnsPortrait = RxInt(3);
  final RxInt pinRowsLandscape = RxInt(1);
  final RxInt pinColumnsLandscape = RxInt(4);

  final RxInt maxAvatarsInGroupWidget = RxInt(4);

  // Desktop settings
  final RxBool launchAtStartup = false.obs;
  final RxBool launchAtStartupMinimized = false.obs;
  final RxBool minimizeToTray = false.obs;
  final RxBool closeToTray = true.obs;
  final RxBool spellcheck = true.obs;
  final RxString spellcheckLanguage = "auto".obs;
  final Rx<WindowEffect> windowEffect = WindowEffect.disabled.obs;
  final RxDouble windowEffectCustomOpacityLight = 0.5.obs;
  final RxDouble windowEffectCustomOpacityDark = 0.5.obs;
  final RxBool desktopNotifications = true.obs;
  final RxInt desktopNotificationSoundVolume = 100.obs;
  final RxnString desktopNotificationSoundPath = RxnString();
  final RxBool windowsTaskbarBadge = true.obs;

  // Troubleshooting settings
  final Rx<Level> logLevel = Level.info.obs;

  // Notification actions
  final RxBool showReplyField = true.obs;
  final RxList<int> selectedActionIndices = Platform.isWindows ? [0, 1, 2, 3].obs : [0, 1, 2].obs;
  final RxList<String> actionList = RxList.from([
    "Mark Read",
    ReactionTypes.LOVE,
    ReactionTypes.LIKE,
    ReactionTypes.LAUGH,
    ReactionTypes.EMPHASIZE,
    ReactionTypes.DISLIKE,
    ReactionTypes.QUESTION
  ]);

  // Text field buttons — enabled buttons, in display order. Absent = hidden.
  final RxList<TextFieldButton> textFieldButtons = RxList.from(TextFieldButton.values);

  // Message options order
  final RxList<DetailsMenuAction> _detailsMenuActions = RxList.from(DetailsMenuAction.values);

  /// Use [setDetailsMenuActions] to set this value
  List<DetailsMenuAction> get detailsMenuActions => _detailsMenuActions;

  // Linux settings
  final Rx<BBTitleBarStyle> titleBarStyle = BBTitleBarStyle.custom.obs;

  // Desktop settings
  final RxBool useDesktopAccent = RxBool(false);

  Future<DisplayMode> getDisplayMode() async {
    List<DisplayMode> modes = await FlutterDisplayMode.supported;
    return modes.firstWhereOrNull((element) => element.refreshRate.round() == refreshRate.value) ?? DisplayMode.auto;
  }

  Future<void> _savePref(String key, dynamic value) async {
    if (value is bool) {
      await PrefsSvc.admin.setBool(key, value);
    } else if (value is String) {
      await PrefsSvc.admin.setString(key, value);
    } else if (value is int) {
      await PrefsSvc.admin.setInt(key, value);
    } else if (value is double) {
      await PrefsSvc.admin.setDouble(key, value);
    } else if (value is List<DetailsMenuAction>) {
      await PrefsSvc.admin.setString(key, jsonEncode(value.map((action) => action.name).toList()));
    } else if (value is List || value is Map) {
      await PrefsSvc.admin.setString(key, jsonEncode(value));
    } else if (value == null) {
      await PrefsSvc.admin.remove(key);
    }
  }

  Settings save() {
    Map<String, dynamic> map = toMap();
    map.forEach((key, value) async {
      await _savePref(key, value);
    });
    return this;
  }

  Future<Settings> saveAsync() async {
    Map<String, dynamic> map = toMap();

    // Ensure the GlobalIsolate's settings are also updated
    await PrefsInterface.syncAllSettings(settings: map);

    // Wait for each key to be saved before moving on
    await Future.forEach(map.entries, (entry) async {
      await _savePref(entry.key, entry.value);
    });

    return this;
  }

  Future<Settings> saveOneAsync(String key) async {
    Map<String, dynamic> map = toMap();
    if (map.containsKey(key)) {
      // Ensure the GlobalIsolate's settings are also updated
      await PrefsInterface.syncSettings({key: map[key]});
      await _savePref(key, map[key]);
    }

    return this;
  }

  Future<Settings> saveManyAsync(List<String> keys) async {
    Map<String, dynamic> map = toMap();
    map.removeWhere((key, value) => !keys.contains(key));

    // Ensure the GlobalIsolate's settings are also updated
    await PrefsInterface.syncSettings(map);

    for (String key in keys) {
      if (map.containsKey(key)) {
        await _savePref(key, map[key]);
      }
    }

    return this;
  }

  static Settings getSettings() {
    Set<String> keys = PrefsSvc.admin.getKeys();

    Map<String, dynamic> items = {};
    for (String s in keys) {
      items[s] = PrefsSvc.admin.get(s);
    }
    if (items.isNotEmpty) {
      return Settings.fromMap(items);
    } else {
      return Settings();
    }
  }

  Map<String, dynamic> toMap({bool includeAll = true}) {
    Map<String, dynamic> map = {
      'autoDownload': autoDownload.value,
      'onlyWifiDownload': onlyWifiDownload.value,
      'maxConcurrentDownloads': maxConcurrentDownloads.value,
      'autoSave': autoSave.value,
      'autoSavePicsLocation': autoSavePicsLocation.value,
      'autoSaveDocsLocation': autoSaveDocsLocation.value,
      'imageQuality': previewImageQuality.value,
      'autoOpenKeyboard': autoOpenKeyboard.value,
      'hideTextPreviews': hideTextPreviews.value,
      'showIncrementalSync': showIncrementalSync.value,
      'highPerfMode': highPerfMode.value,
      'reduceMotion': reduceMotion.value,
      'lastIncrementalSync': lastIncrementalSync.value,
      'lastIncrementalSyncRowId': lastIncrementalSyncRowId.value,
      'refreshRate': refreshRate.value,
      'colorfulAvatars': colorfulAvatars.value,
      'colorfulBubbles': colorfulBubbles.value,
      'hideDividers': hideDividers.value,
      'scrollVelocity': scrollVelocity.value,
      'sendWithReturn': sendWithReturn.value,
      'doubleTapForDetails': doubleTapForDetails.value,
      'denseChatTiles': denseChatTiles.value,
      'smartReply': smartReply.value,
      'showSyncIndicator': showSyncIndicator.value,
      'sendDelay': sendDelay.value,
      'recipientAsPlaceholder': recipientAsPlaceholder.value,
      'hideKeyboardOnScroll': hideKeyboardOnScroll.value,
      'moveChatCreatorToHeader': moveChatCreatorToHeader.value,
      'showFiltersInHeader': showFiltersInHeader.value,
      'showCustomGroupFilterChips': showCustomGroupFilterChips.value,
      'cameraFAB': cameraFAB.value,
      'swipeToCloseKeyboard': swipeToCloseKeyboard.value,
      'swipeToOpenKeyboard': swipeToOpenKeyboard.value,
      'openKeyboardOnSTB': openKeyboardOnSTB.value,
      'swipableConversationTiles': swipableConversationTiles.value,
      'showDeliveryTimestamps': showDeliveryTimestamps.value,
      'filteredChatList': filteredChatList.value,
      'startVideosMuted': startVideosMuted.value,
      'startVideosMutedFullscreen': startVideosMutedFullscreen.value,
      'use24HrFormat': use24HrFormat.value,
      'alwaysShowAvatars': alwaysShowAvatars.value,
      'notifyOnChatList': notifyOnChatList.value,
      'notifyReactions': notifyReactions.value,
      'globalTextDetection': globalTextDetection.value,
      'filterUnknownSenders': filterUnknownSenders.value,
      'savedChatFilters': Map<String, String>.from(savedChatFilters.value),
      'tabletMode': tabletMode.value,
      'immersiveMode': immersiveMode.value,
      'avatarScale': avatarScale.value,
      'launchAtStartup': launchAtStartup.value,
      'launchAtStartupMinimized': launchAtStartupMinimized.value,
      'closeToTray': closeToTray.value,
      'spellcheck': spellcheck.value,
      'spellcheckLanguage': spellcheckLanguage.value,
      'minimizeToTray': minimizeToTray.value,
      'showReplyField': showReplyField.value,
      'selectedActionIndices': List<int>.from(selectedActionIndices),
      'actionList': List<String>.from(actionList),
      'detailsMenuActions': detailsMenuActions.map((action) => action.name).toList(),
      'textFieldButtons': textFieldButtons.map((button) => button.name).toList(),
      'askWhereToSave': askWhereToSave.value,
      'statusIndicatorsOnChats': statusIndicatorsOnChats.value,
      'apiTimeout': apiTimeout.value,
      'allowUpsideDownRotation': allowUpsideDownRotation.value,
      'cancelQueuedMessages': cancelQueuedMessages.value,
      'repliesToPrevious': repliesToPrevious.value,
      'useLocalhost': localhostPort.value,
      'useLocalIpv6': useLocalIpv6.value,
      'soundVolume': soundVolume.value,
      'syncContactsAutomatically': syncContactsAutomatically.value,
      'scrollToBottomOnSend': scrollToBottomOnSend.value,
      'sendEventsToTasker': sendEventsToTasker.value,
      'keepAppAlive': keepAppAlive.value,
      'unarchiveOnNewMessage': unarchiveOnNewMessage.value,
      'scrollToLastUnread': scrollToLastUnread.value,
      'userName': userName.value,
      'privateAPISend': privateAPISend.value,
      'privateAPIAttachmentSend': privateAPIAttachmentSend.value,
      'enableUnifiedPush': enableUnifiedPush.value,
      'endpointUnifiedPush': endpointUnifiedPush.value,
      'highlightSelectedChat': highlightSelectedChat.value,
      'enablePrivateAPI': enablePrivateAPI.value,
      'privateSendTypingIndicators': privateSendTypingIndicators.value,
      'privateMarkChatAsRead': privateMarkChatAsRead.value,
      'privateManualMarkAsRead': privateManualMarkAsRead.value,
      'privateSubjectLine': privateSubjectLine.value,
      'editLastSentMessageOnUpArrow': editLastSentMessageOnUpArrow.value,
      'redactedMode': redactedMode.value,
      'hideMessageContent': hideMessageContent.value,
      'hideAttachments': hideAttachments.value,
      'hideContactInfo': hideContactInfo.value,
      'generateFakeAvatars': generateFakeAvatars.value,
      'generateFakeMessageContent': hideMessageContent.value,
      'enableQuickTapback': enableQuickTapback.value,
      'quickTapbackType': quickTapbackType.value,
      'notificationReactionAction': notificationReactionAction.value,
      'notificationReactionActionType': notificationReactionActionType.value,
      'materialRightAction': materialRightAction.value.index,
      'materialLeftAction': materialLeftAction.value.index,
      'shouldSecure': shouldSecure.value,
      'securityLevel': securityLevel.value.index,
      'incognitoKeyboard': incognitoKeyboard.value,
      'skin': skin.value.index,
      'theme': theme.value.index,
      'fullscreenViewerSwipeDir': fullscreenViewerSwipeDir.value.index,
      'pinRowsPortrait': pinRowsPortrait.value,
      'pinColumnsPortrait': pinColumnsPortrait.value,
      'pinRowsLandscape': pinRowsLandscape.value,
      'pinColumnsLandscape': pinColumnsLandscape.value,
      'maxAvatarsInGroupWidget': maxAvatarsInGroupWidget.value,
      'titleBarStyle': titleBarStyle.value.index,
      'windowEffect': windowEffect.value.name,
      'windowEffectCustomOpacityLight': windowEffectCustomOpacityLight.value,
      'windowEffectCustomOpacityDark': windowEffectCustomOpacityDark.value,
      'desktopNotifications': desktopNotifications.value,
      'desktopNotificationSoundVolume': desktopNotificationSoundVolume.value,
      'windowsTaskbarBadge': windowsTaskbarBadge.value,
      'useDesktopAccent': useDesktopAccent.value,
      'logLevel': logLevel.value.index,
      'hideNamesForReactions': hideNamesForReactions.value,
      'replaceEmoticonsWithEmoji': replaceEmoticonsWithEmoji.value,
      'lastReviewRequestTimestamp': lastReviewRequestTimestamp.value,
      'serverPrivateAPI': serverPrivateAPI.value,
      'iMessageStatsSource': iMessageStatsSource.value,
    };

    if (includeAll) {
      map.addAll({
        'iCloudAccount': iCloudAccount.value,
        'guidAuthKey': guidAuthKey.value,
        'serverAddress': serverAddress.value,
        'customHeaders': Map<String, String>.from(customHeaders.value),
        'finishedSetup': finishedSetup.value,
        'reachedConversationList': reachedConversationList.value,
        'colorsFromMedia': colorsFromMedia.value,
        'userAvatarPath': userAvatarPath.value,
        'firstFcmRegisterDate': firstFcmRegisterDate.value,
        'sendSoundPath': sendSoundPath.value,
        'receiveSoundPath': receiveSoundPath.value,
        'desktopNotificationSoundPath': desktopNotificationSoundPath.value,
      });
    }

    return map;
  }

  static void updateFromMap(Map<String, dynamic> map) {
    SettingsSvc.settings.iCloudAccount.value = map['iCloudAccount'] ?? SettingsSvc.settings.iCloudAccount.value;
    SettingsSvc.settings.serverAddress.value = map['serverAddress'] ?? SettingsSvc.settings.serverAddress.value;
    SettingsSvc.settings.guidAuthKey.value = map['guidAuthKey'] ?? SettingsSvc.settings.guidAuthKey.value;
    if (map.containsKey('customHeaders')) {
      debugPrint('Updating custom headers from map: ${map['customHeaders']}');
      SettingsSvc.settings.customHeaders.value = _processCustomHeaders(map['customHeaders']);
    }
    SettingsSvc.settings.finishedSetup.value = map['finishedSetup'] ?? SettingsSvc.settings.finishedSetup.value;
    SettingsSvc.settings.reachedConversationList.value =
        map['reachedConversationList'] ?? SettingsSvc.settings.reachedConversationList.value;
    SettingsSvc.settings.autoDownload.value = map['autoDownload'] ?? SettingsSvc.settings.autoDownload.value;
    SettingsSvc.settings.onlyWifiDownload.value =
        map['onlyWifiDownload'] ?? SettingsSvc.settings.onlyWifiDownload.value;
    SettingsSvc.settings.maxConcurrentDownloads.value =
        map['maxConcurrentDownloads'] ?? SettingsSvc.settings.maxConcurrentDownloads.value;
    SettingsSvc.settings.autoSave.value = map['autoSave'] ?? SettingsSvc.settings.autoSave.value;
    SettingsSvc.settings.autoSavePicsLocation.value =
        map['autoSavePicsLocation'] ?? SettingsSvc.settings.autoSavePicsLocation.value;
    SettingsSvc.settings.autoSaveDocsLocation.value =
        map['autoSaveDocsLocation'] ?? SettingsSvc.settings.autoSaveDocsLocation.value;
    SettingsSvc.settings.previewImageQuality.value =
        map['imageQuality']?.toDouble() ?? SettingsSvc.settings.previewImageQuality.value;
    SettingsSvc.settings.autoOpenKeyboard.value =
        map['autoOpenKeyboard'] ?? SettingsSvc.settings.autoOpenKeyboard.value;
    SettingsSvc.settings.hideTextPreviews.value =
        map['hideTextPreviews'] ?? SettingsSvc.settings.hideTextPreviews.value;
    SettingsSvc.settings.showIncrementalSync.value =
        map['showIncrementalSync'] ?? SettingsSvc.settings.showIncrementalSync.value;
    SettingsSvc.settings.highPerfMode.value = map['highPerfMode'] ?? SettingsSvc.settings.highPerfMode.value;
    SettingsSvc.settings.reduceMotion.value = map['reduceMotion'] ?? SettingsSvc.settings.reduceMotion.value;
    SettingsSvc.settings.lastIncrementalSync.value =
        map['lastIncrementalSync'] ?? SettingsSvc.settings.lastIncrementalSync.value;
    SettingsSvc.settings.lastIncrementalSyncRowId.value =
        map['lastIncrementalSyncRowId'] ?? SettingsSvc.settings.lastIncrementalSyncRowId.value;
    SettingsSvc.settings.refreshRate.value = map['refreshRate'] ?? SettingsSvc.settings.refreshRate.value;
    SettingsSvc.settings.colorfulAvatars.value = map['colorfulAvatars'] ?? SettingsSvc.settings.colorfulAvatars.value;
    SettingsSvc.settings.colorfulBubbles.value = map['colorfulBubbles'] ?? SettingsSvc.settings.colorfulBubbles.value;
    SettingsSvc.settings.hideDividers.value = map['hideDividers'] ?? SettingsSvc.settings.hideDividers.value;
    SettingsSvc.settings.scrollVelocity.value =
        map['scrollVelocity']?.toDouble() ?? SettingsSvc.settings.scrollVelocity.value;
    SettingsSvc.settings.sendWithReturn.value = map['sendWithReturn'] ?? SettingsSvc.settings.sendWithReturn.value;
    SettingsSvc.settings.doubleTapForDetails.value =
        map['doubleTapForDetails'] ?? SettingsSvc.settings.doubleTapForDetails.value;
    SettingsSvc.settings.denseChatTiles.value = map['denseChatTiles'] ?? SettingsSvc.settings.denseChatTiles.value;
    SettingsSvc.settings.smartReply.value = map['smartReply'] ?? SettingsSvc.settings.smartReply.value;
    SettingsSvc.settings.showSyncIndicator.value =
        map['showSyncIndicator'] ?? SettingsSvc.settings.showSyncIndicator.value;
    SettingsSvc.settings.sendDelay.value = map['sendDelay'] ?? SettingsSvc.settings.sendDelay.value;
    SettingsSvc.settings.recipientAsPlaceholder.value =
        map['recipientAsPlaceholder'] ?? SettingsSvc.settings.recipientAsPlaceholder.value;
    SettingsSvc.settings.hideKeyboardOnScroll.value =
        map['hideKeyboardOnScroll'] ?? SettingsSvc.settings.hideKeyboardOnScroll.value;
    SettingsSvc.settings.moveChatCreatorToHeader.value =
        map['moveChatCreatorToHeader'] ?? SettingsSvc.settings.moveChatCreatorToHeader.value;
    SettingsSvc.settings.showFiltersInHeader.value =
        map['showFiltersInHeader'] ?? SettingsSvc.settings.showFiltersInHeader.value;
    SettingsSvc.settings.showCustomGroupFilterChips.value =
        map['showCustomGroupFilterChips'] ?? SettingsSvc.settings.showCustomGroupFilterChips.value;
    SettingsSvc.settings.cameraFAB.value = map['cameraFAB'] ?? SettingsSvc.settings.cameraFAB.value;
    SettingsSvc.settings.swipeToCloseKeyboard.value =
        map['swipeToCloseKeyboard'] ?? SettingsSvc.settings.swipeToCloseKeyboard.value;
    SettingsSvc.settings.swipeToOpenKeyboard.value =
        map['swipeToOpenKeyboard'] ?? SettingsSvc.settings.swipeToOpenKeyboard.value;
    SettingsSvc.settings.openKeyboardOnSTB.value =
        map['openKeyboardOnSTB'] ?? SettingsSvc.settings.openKeyboardOnSTB.value;
    SettingsSvc.settings.swipableConversationTiles.value =
        map['swipableConversationTiles'] ?? SettingsSvc.settings.swipableConversationTiles.value;
    SettingsSvc.settings.showDeliveryTimestamps.value =
        map['showDeliveryTimestamps'] ?? SettingsSvc.settings.showDeliveryTimestamps.value;
    SettingsSvc.settings.filteredChatList.value =
        map['filteredChatList'] ?? SettingsSvc.settings.filteredChatList.value;
    SettingsSvc.settings.startVideosMuted.value =
        map['startVideosMuted'] ?? SettingsSvc.settings.startVideosMuted.value;
    SettingsSvc.settings.startVideosMutedFullscreen.value =
        map['startVideosMutedFullscreen'] ?? SettingsSvc.settings.startVideosMutedFullscreen.value;
    SettingsSvc.settings.use24HrFormat.value = map['use24HrFormat'] ?? SettingsSvc.settings.use24HrFormat.value;
    SettingsSvc.settings.alwaysShowAvatars.value =
        map['alwaysShowAvatars'] ?? SettingsSvc.settings.alwaysShowAvatars.value;
    SettingsSvc.settings.notifyOnChatList.value =
        map['notifyOnChatList'] ?? SettingsSvc.settings.notifyOnChatList.value;
    SettingsSvc.settings.notifyReactions.value = map['notifyReactions'] ?? SettingsSvc.settings.notifyReactions.value;
    SettingsSvc.settings.colorsFromMedia.value = map['colorsFromMedia'] ?? SettingsSvc.settings.colorsFromMedia.value;
    SettingsSvc.settings.globalTextDetection.value =
        map['globalTextDetection'] ?? SettingsSvc.settings.globalTextDetection.value;
    SettingsSvc.settings.filterUnknownSenders.value =
        map['filterUnknownSenders'] ?? SettingsSvc.settings.filterUnknownSenders.value;
    if (map.containsKey('savedChatFilters')) {
      SettingsSvc.settings.savedChatFilters.value = _processSavedChatFilters(map['savedChatFilters']);
    }
    SettingsSvc.settings.tabletMode.value = kIsDesktop || (map['tabletMode'] ?? SettingsSvc.settings.tabletMode.value);
    SettingsSvc.settings.highlightSelectedChat.value =
        map['highlightSelectedChat'] ?? SettingsSvc.settings.highlightSelectedChat.value;
    SettingsSvc.settings.immersiveMode.value = map['immersiveMode'] ?? SettingsSvc.settings.immersiveMode.value;
    SettingsSvc.settings.avatarScale.value = map['avatarScale']?.toDouble() ?? SettingsSvc.settings.avatarScale.value;
    SettingsSvc.settings.launchAtStartup.value = map['launchAtStartup'] ?? SettingsSvc.settings.launchAtStartup.value;
    SettingsSvc.settings.launchAtStartupMinimized.value =
        map['launchAtStartupMinimized'] ?? SettingsSvc.settings.launchAtStartupMinimized.value;
    SettingsSvc.settings.closeToTray.value = map['closeToTray'] ?? SettingsSvc.settings.closeToTray.value;
    SettingsSvc.settings.spellcheck.value = map['spellcheck'] ?? SettingsSvc.settings.spellcheck.value;
    SettingsSvc.settings.spellcheckLanguage.value =
        map['spellcheckLanguage'] ?? SettingsSvc.settings.spellcheckLanguage.value;
    SettingsSvc.settings.minimizeToTray.value = map['minimizeToTray'] ?? SettingsSvc.settings.minimizeToTray.value;
    SettingsSvc.settings.askWhereToSave.value = map['askWhereToSave'] ?? SettingsSvc.settings.askWhereToSave.value;
    SettingsSvc.settings.statusIndicatorsOnChats.value =
        map['statusIndicatorsOnChats'] ?? SettingsSvc.settings.statusIndicatorsOnChats.value;
    SettingsSvc.settings.apiTimeout.value = map['apiTimeout'] ?? SettingsSvc.settings.apiTimeout.value;
    SettingsSvc.settings.allowUpsideDownRotation.value =
        map['allowUpsideDownRotation'] ?? SettingsSvc.settings.allowUpsideDownRotation.value;
    SettingsSvc.settings.cancelQueuedMessages.value =
        map['cancelQueuedMessages'] ?? SettingsSvc.settings.cancelQueuedMessages.value;
    SettingsSvc.settings.repliesToPrevious.value =
        map['repliesToPrevious'] ?? SettingsSvc.settings.repliesToPrevious.value;
    SettingsSvc.settings.localhostPort.value = map['useLocalhost'] ?? SettingsSvc.settings.localhostPort.value;
    SettingsSvc.settings.useLocalIpv6.value = map['useLocalIpv6'] ?? SettingsSvc.settings.useLocalIpv6.value;
    SettingsSvc.settings.sendSoundPath.value = map['sendSoundPath'] ?? SettingsSvc.settings.sendSoundPath.value;
    SettingsSvc.settings.receiveSoundPath.value =
        map['receiveSoundPath'] ?? SettingsSvc.settings.receiveSoundPath.value;
    SettingsSvc.settings.soundVolume.value = map['soundVolume'] ?? SettingsSvc.settings.soundVolume.value;
    SettingsSvc.settings.syncContactsAutomatically.value =
        map['syncContactsAutomatically'] ?? SettingsSvc.settings.syncContactsAutomatically.value;
    SettingsSvc.settings.scrollToBottomOnSend.value =
        map['scrollToBottomOnSend'] ?? SettingsSvc.settings.scrollToBottomOnSend.value;
    SettingsSvc.settings.sendEventsToTasker.value =
        map['sendEventsToTasker'] ?? SettingsSvc.settings.sendEventsToTasker.value;
    SettingsSvc.settings.keepAppAlive.value = map['keepAppAlive'] ?? SettingsSvc.settings.keepAppAlive.value;
    SettingsSvc.settings.unarchiveOnNewMessage.value =
        map['unarchiveOnNewMessage'] ?? SettingsSvc.settings.unarchiveOnNewMessage.value;
    SettingsSvc.settings.scrollToLastUnread.value =
        map['scrollToLastUnread'] ?? SettingsSvc.settings.scrollToLastUnread.value;
    SettingsSvc.settings.userName.value = map['userName'] ?? SettingsSvc.settings.userName.value;
    SettingsSvc.settings.userAvatarPath.value = map['userAvatarPath'] ?? SettingsSvc.settings.userAvatarPath.value;
    SettingsSvc.settings.privateAPISend.value = map['privateAPISend'] ?? SettingsSvc.settings.privateAPISend.value;
    SettingsSvc.settings.privateAPIAttachmentSend.value =
        map['privateAPIAttachmentSend'] ?? SettingsSvc.settings.privateAPIAttachmentSend.value;
    SettingsSvc.settings.enablePrivateAPI.value =
        map['enablePrivateAPI'] ?? SettingsSvc.settings.enablePrivateAPI.value;
    SettingsSvc.settings.serverPrivateAPI.value =
        map['serverPrivateAPI'] ?? SettingsSvc.settings.serverPrivateAPI.value;
    SettingsSvc.settings.iMessageStatsSource.value = (map['iMessageStatsSource'] == 'local') ? 'local' : 'server';
    SettingsSvc.settings.privateSendTypingIndicators.value =
        map['privateSendTypingIndicators'] ?? SettingsSvc.settings.privateSendTypingIndicators.value;
    SettingsSvc.settings.privateMarkChatAsRead.value =
        map['privateMarkChatAsRead'] ?? SettingsSvc.settings.privateMarkChatAsRead.value;
    SettingsSvc.settings.privateManualMarkAsRead.value =
        map['privateManualMarkAsRead'] ?? SettingsSvc.settings.privateManualMarkAsRead.value;
    SettingsSvc.settings.privateSubjectLine.value =
        map['privateSubjectLine'] ?? SettingsSvc.settings.privateSubjectLine.value;
    SettingsSvc.settings.editLastSentMessageOnUpArrow.value =
        map['editLastSentMessageOnUpArrow'] ?? SettingsSvc.settings.editLastSentMessageOnUpArrow.value;
    SettingsSvc.settings.redactedMode.value = map['redactedMode'] ?? SettingsSvc.settings.redactedMode.value;
    SettingsSvc.settings.hideMessageContent.value =
        map['hideMessageContent'] ?? SettingsSvc.settings.hideMessageContent.value;
    SettingsSvc.settings.hideAttachments.value = map['hideAttachments'] ?? SettingsSvc.settings.hideAttachments.value;
    SettingsSvc.settings.hideContactInfo.value = map['hideContactInfo'] ?? SettingsSvc.settings.hideContactInfo.value;
    SettingsSvc.settings.generateFakeAvatars.value =
        map['generateFakeAvatars'] ?? SettingsSvc.settings.generateFakeAvatars.value;
    SettingsSvc.settings.hideMessageContent.value =
        map['generateFakeMessageContent'] ?? SettingsSvc.settings.hideMessageContent.value;
    SettingsSvc.settings.enableUnifiedPush.value =
        map['enableUnifiedPush'] ?? SettingsSvc.settings.enableUnifiedPush.value;
    SettingsSvc.settings.endpointUnifiedPush.value =
        map['endpointUnifiedPush'] ?? SettingsSvc.settings.endpointUnifiedPush.value;
    SettingsSvc.settings.enableQuickTapback.value =
        map['enableQuickTapback'] ?? SettingsSvc.settings.enableQuickTapback.value;
    SettingsSvc.settings.quickTapbackType.value =
        map['quickTapbackType'] ?? SettingsSvc.settings.quickTapbackType.value;
    SettingsSvc.settings.notificationReactionAction.value =
        map['notificationReactionAction'] ?? SettingsSvc.settings.notificationReactionAction.value;
    SettingsSvc.settings.notificationReactionActionType.value =
        map['notificationReactionActionType'] ?? SettingsSvc.settings.notificationReactionActionType.value;
    SettingsSvc.settings.materialRightAction.value = map['materialRightAction'] != null
        ? MaterialSwipeAction.values[map['materialRightAction']]
        : SettingsSvc.settings.materialRightAction.value;
    SettingsSvc.settings.materialLeftAction.value = map['materialLeftAction'] != null
        ? MaterialSwipeAction.values[map['materialLeftAction']]
        : SettingsSvc.settings.materialLeftAction.value;
    SettingsSvc.settings.shouldSecure.value = map['shouldSecure'] ?? SettingsSvc.settings.shouldSecure.value;
    SettingsSvc.settings.securityLevel.value = map['securityLevel'] != null
        ? SecurityLevel.values[map['securityLevel']]
        : SettingsSvc.settings.securityLevel.value;
    SettingsSvc.settings.incognitoKeyboard.value =
        map['incognitoKeyboard'] ?? SettingsSvc.settings.incognitoKeyboard.value;
    SettingsSvc.settings.skin.value = map['skin'] != null ? Skins.values[map['skin']] : SettingsSvc.settings.skin.value;
    SettingsSvc.settings.theme.value =
        map['theme'] != null ? ThemeMode.values[map['theme']] : SettingsSvc.settings.theme.value;
    SettingsSvc.settings.fullscreenViewerSwipeDir.value = map['fullscreenViewerSwipeDir'] != null
        ? SwipeDirection.values[map['fullscreenViewerSwipeDir']]
        : SettingsSvc.settings.fullscreenViewerSwipeDir.value;
    SettingsSvc.settings.pinRowsPortrait.value = map['pinRowsPortrait'] ?? SettingsSvc.settings.pinRowsPortrait.value;
    SettingsSvc.settings.pinColumnsPortrait.value =
        map['pinColumnsPortrait'] ?? SettingsSvc.settings.pinColumnsPortrait.value;
    SettingsSvc.settings.pinRowsLandscape.value =
        map['pinRowsLandscape'] ?? SettingsSvc.settings.pinRowsLandscape.value;
    SettingsSvc.settings.pinColumnsLandscape.value =
        map['pinColumnsLandscape'] ?? SettingsSvc.settings.pinColumnsLandscape.value;
    SettingsSvc.settings.maxAvatarsInGroupWidget.value =
        map['maxAvatarsInGroupWidget'] ?? SettingsSvc.settings.maxAvatarsInGroupWidget.value;
    SettingsSvc.settings.titleBarStyle.value = map['titleBarStyle'] != null
        ? BBTitleBarStyle.values[map['titleBarStyle']]
        : map['useCustomTitleBar'] == false
            ? BBTitleBarStyle.native
            : SettingsSvc.settings.titleBarStyle.value;

    SettingsSvc.settings.showReplyField.value = map['showReplyField'] ?? SettingsSvc.settings.showReplyField.value;
    if (map.containsKey('selectedActionIndices')) {
      SettingsSvc.settings.selectedActionIndices.value =
          _processSelectedActionIndices(map['selectedActionIndices'], SettingsSvc.settings.showReplyField.value);
    }
    SettingsSvc.settings.actionList.value =
        _processActionList(map['actionList'] ?? jsonEncode(List<String>.from(SettingsSvc.settings.actionList)));
    if (map.containsKey('detailsMenuActions')) {
      SettingsSvc.settings._detailsMenuActions.value =
          _processDetailsMenuActions(map['detailsMenuActions'], SettingsSvc.settings.detailsMenuActions);
    }
    if (map.containsKey('textFieldButtons')) {
      SettingsSvc.settings.textFieldButtons.value = _processTextFieldButtons(map['textFieldButtons']);
    }

    SettingsSvc.settings.windowEffect.value = kIsDesktop && Platform.isWindows
        ? WindowEffect.values.firstWhereOrNull((e) => e.name == map['windowEffect']) ??
            SettingsSvc.settings.windowEffect.value
        : SettingsSvc.settings.windowEffect.value;
    SettingsSvc.settings.windowEffectCustomOpacityLight.value =
        map['windowEffectCustomOpacityLight']?.toDouble() ?? SettingsSvc.settings.windowEffectCustomOpacityLight.value;
    SettingsSvc.settings.windowEffectCustomOpacityDark.value =
        map['windowEffectCustomOpacityDark']?.toDouble() ?? SettingsSvc.settings.windowEffectCustomOpacityDark.value;
    SettingsSvc.settings.desktopNotifications.value =
        map['desktopNotifications'] ?? SettingsSvc.settings.desktopNotifications.value;
    SettingsSvc.settings.desktopNotificationSoundVolume.value =
        map['desktopNotificationSoundVolume'] ?? SettingsSvc.settings.desktopNotificationSoundVolume.value;
    SettingsSvc.settings.windowsTaskbarBadge.value =
        map['windowsTaskbarBadge'] ?? SettingsSvc.settings.windowsTaskbarBadge.value;
    SettingsSvc.settings.desktopNotificationSoundPath.value =
        map['desktopNotificationSoundPath'] ?? SettingsSvc.settings.desktopNotificationSoundPath.value;
    SettingsSvc.settings.useDesktopAccent.value =
        map['useDesktopAccent'] ?? map['useWindowsAccent'] ?? SettingsSvc.settings.useDesktopAccent.value;
    SettingsSvc.settings.firstFcmRegisterDate.value =
        map['firstFcmRegisterDate'] ?? SettingsSvc.settings.firstFcmRegisterDate.value;
    SettingsSvc.settings.logLevel.value =
        map['logLevel'] != null ? Level.values[map['logLevel']] : SettingsSvc.settings.logLevel.value;
    SettingsSvc.settings.hideNamesForReactions.value =
        map['hideNamesForReactions'] ?? SettingsSvc.settings.hideNamesForReactions.value;
    SettingsSvc.settings.replaceEmoticonsWithEmoji.value =
        map['replaceEmoticonsWithEmoji'] ?? SettingsSvc.settings.replaceEmoticonsWithEmoji.value;
    SettingsSvc.settings.lastReviewRequestTimestamp.value =
        map['lastReviewRequestTimestamp'] ?? SettingsSvc.settings.lastReviewRequestTimestamp.value;
    SettingsSvc.settings.save();

    if (!isIsolate) {
      unawaited(PrefsInterface.syncAllSettings());
      EventDispatcherSvc.emit("theme-update", null);
    }
  }

  static Settings fromMap(Map<String, dynamic> map) {
    Settings s = Settings();
    s.iCloudAccount.value = map['iCloudAccount'] ?? "";
    s.guidAuthKey.value = map['guidAuthKey'] ?? "";
    s.serverAddress.value = map['serverAddress'] ?? "";
    debugPrint('Loading Custom Headers from map: ${map['customHeaders']}');
    s.customHeaders.value = _processCustomHeaders(map['customHeaders']);
    s.finishedSetup.value = map['finishedSetup'] ?? false;
    s.reachedConversationList.value = map['reachedConversationList'] ?? false;
    s.autoDownload.value = map['autoDownload'] ?? true;
    s.onlyWifiDownload.value = map['onlyWifiDownload'] ?? false;
    s.maxConcurrentDownloads.value = map['maxConcurrentDownloads'] ?? 2;
    s.autoSave.value = map['autoSave'] ?? false;
    s.autoSavePicsLocation.value = map['autoSavePicsLocation'] ?? "Pictures";
    s.autoSaveDocsLocation.value = map['autoSaveDocsLocation'] ?? FilesystemService.androidDownloadsPath;
    s.previewImageQuality.value = map['imageQuality']?.toDouble() ?? 1.0;
    s.autoOpenKeyboard.value = map['autoOpenKeyboard'] ?? true;
    s.hideTextPreviews.value = map['hideTextPreviews'] ?? false;
    s.showIncrementalSync.value = map['showIncrementalSync'] ?? false;
    s.highPerfMode.value = map['highPerfMode'] ?? false;
    s.reduceMotion.value = map['reduceMotion'] ?? false;
    s.lastIncrementalSync.value = map['lastIncrementalSync'] ?? 0;
    s.lastIncrementalSyncRowId.value = map['lastIncrementalSyncRowId'] ?? 0;
    s.refreshRate.value = map['refreshRate'] ?? 0;
    s.colorfulAvatars.value = map['colorfulAvatars'] ?? false;
    s.colorfulBubbles.value = map['colorfulBubbles'] ?? false;
    s.hideDividers.value = map['hideDividers'] ?? false;
    s.scrollVelocity.value = map['scrollVelocity']?.toDouble() ?? 1;
    s.sendWithReturn.value = map['sendWithReturn'] ?? false;
    s.doubleTapForDetails.value = map['doubleTapForDetails'] ?? false;
    s.denseChatTiles.value = map['denseChatTiles'] ?? false;
    s.smartReply.value = map['smartReply'] ?? false;
    s.showSyncIndicator.value = map['showSyncIndicator'] ?? true;
    s.sendDelay.value = map['sendDelay'] ?? 0;
    s.recipientAsPlaceholder.value = map['recipientAsPlaceholder'] ?? false;
    s.hideKeyboardOnScroll.value = map['hideKeyboardOnScroll'] ?? false;
    s.moveChatCreatorToHeader.value = map['moveChatCreatorToHeader'] ?? false;
    s.showFiltersInHeader.value = map['showFiltersInHeader'] ?? false;
    s.showCustomGroupFilterChips.value = map['showCustomGroupFilterChips'] ?? false;
    s.cameraFAB.value = map['cameraFAB'] ?? false;
    s.swipeToCloseKeyboard.value = map['swipeToCloseKeyboard'] ?? false;
    s.swipeToOpenKeyboard.value = map['swipeToOpenKeyboard'] ?? false;
    s.openKeyboardOnSTB.value = map['openKeyboardOnSTB'] ?? false;
    s.swipableConversationTiles.value = map['swipableConversationTiles'] ?? false;
    s.showDeliveryTimestamps.value = map['showDeliveryTimestamps'] ?? false;
    s.filteredChatList.value = map['filteredChatList'] ?? false;
    s.startVideosMuted.value = map['startVideosMuted'] ?? true;
    s.startVideosMutedFullscreen.value = map['startVideosMutedFullscreen'] ?? true;
    s.use24HrFormat.value = map['use24HrFormat'] ?? false;
    s.alwaysShowAvatars.value = map['alwaysShowAvatars'] ?? false;
    s.notifyOnChatList.value = map['notifyOnChatList'] ?? false;
    s.notifyReactions.value = map['notifyReactions'] ?? true;
    s.colorsFromMedia.value = map['colorsFromMedia'] ?? false;
    s.globalTextDetection.value = map['globalTextDetection'] ?? "";
    s.filterUnknownSenders.value = map['filterUnknownSenders'] ?? false;
    s.savedChatFilters.value = _processSavedChatFilters(map['savedChatFilters']);
    s.tabletMode.value = kIsDesktop || (map['tabletMode'] ?? true);
    s.highlightSelectedChat.value = map['highlightSelectedChat'] ?? true;
    s.immersiveMode.value = map['immersiveMode'] ?? true;
    s.avatarScale.value = map['avatarScale']?.toDouble() ?? 1.0;
    s.launchAtStartup.value = map['launchAtStartup'] ?? false;
    s.launchAtStartupMinimized.value = map['launchAtStartupMinimized'] ?? false;
    s.closeToTray.value = map['closeToTray'] ?? true;
    s.spellcheck.value = map['spellcheck'] ?? true;
    s.spellcheckLanguage.value = map['spellcheckLanguage'] ?? 'auto';
    s.minimizeToTray.value = map['minimizeToTray'] ?? false;
    s.askWhereToSave.value = map['askWhereToSave'] ?? false;
    s.statusIndicatorsOnChats.value = map['statusIndicatorsOnChats'] ?? false;
    s.apiTimeout.value = map['apiTimeout'] ?? 30000;
    s.allowUpsideDownRotation.value = map['allowUpsideDownRotation'] ?? false;
    s.cancelQueuedMessages.value = map['cancelQueuedMessages'] ?? false;
    s.repliesToPrevious.value = map['repliesToPrevious'] ?? false;
    s.localhostPort.value = map['useLocalhost'];
    s.useLocalIpv6.value = map['useLocalIpv6'] ?? false;
    s.sendSoundPath.value = map['sendSoundPath'];
    s.receiveSoundPath.value = map['receiveSoundPath'];
    s.soundVolume.value = map['soundVolume'] ?? 100;
    s.syncContactsAutomatically.value = map['syncContactsAutomatically'] ?? false;
    s.scrollToBottomOnSend.value = map['scrollToBottomOnSend'] ?? true;
    s.sendEventsToTasker.value = map['sendEventsToTasker'] ?? false;
    s.keepAppAlive.value = map['keepAppAlive'] ?? false;
    s.unarchiveOnNewMessage.value = map['unarchiveOnNewMessage'] ?? false;
    s.scrollToLastUnread.value = map['scrollToLastUnread'] ?? false;
    s.userName.value = map['userName'] ?? "You";
    s.userAvatarPath.value = map['userAvatarPath'];
    s.privateAPISend.value = map['privateAPISend'] ?? false;
    s.privateAPIAttachmentSend.value = map['privateAPIAttachmentSend'] ?? false;
    s.enablePrivateAPI.value = map['enablePrivateAPI'] ?? false;
    s.serverPrivateAPI.value = map['serverPrivateAPI'];
    s.iMessageStatsSource.value = (map['iMessageStatsSource'] == 'local') ? 'local' : 'server';
    s.privateSendTypingIndicators.value = map['privateSendTypingIndicators'] ?? false;
    s.privateMarkChatAsRead.value = map['privateMarkChatAsRead'] ?? false;
    s.privateManualMarkAsRead.value = map['privateManualMarkAsRead'] ?? false;
    s.privateSubjectLine.value = map['privateSubjectLine'] ?? false;
    s.editLastSentMessageOnUpArrow.value = map['editLastSentMessageOnUpArrow'] ?? false;
    s.redactedMode.value = map['redactedMode'] ?? false;
    s.hideMessageContent.value = map['hideMessageContent'] ?? true;
    s.hideAttachments.value = map['hideAttachments'] ?? true;
    s.hideContactInfo.value = map['hideContactInfo'] ?? true;
    s.generateFakeAvatars.value = map['generateFakeAvatars'] ?? false;
    s.hideMessageContent.value = map['generateFakeMessageContent'] ?? false;
    s.enableUnifiedPush.value = map['enableUnifiedPush'] ?? false;
    s.endpointUnifiedPush.value = map['endpointUnifiedPush'] ?? "";
    s.enableQuickTapback.value = map['enableQuickTapback'] ?? false;
    s.quickTapbackType.value = map['quickTapbackType'] ?? ReactionTypes.toList()[0];
    s.notificationReactionAction.value = map['notificationReactionAction'] ?? true;
    s.notificationReactionActionType.value = map['notificationReactionActionType'] ?? ReactionTypes.LIKE;
    s.materialRightAction.value = map['materialRightAction'] != null
        ? MaterialSwipeAction.values[map['materialRightAction']]
        : MaterialSwipeAction.pin;
    s.materialLeftAction.value = map['materialLeftAction'] != null
        ? MaterialSwipeAction.values[map['materialLeftAction']]
        : MaterialSwipeAction.archive;
    s.shouldSecure.value = map['shouldSecure'] ?? false;
    s.securityLevel.value =
        map['securityLevel'] != null ? SecurityLevel.values[map['securityLevel']] : SecurityLevel.locked;
    s.incognitoKeyboard.value = map['incognitoKeyboard'] ?? false;
    s.skin.value = map['skin'] != null ? Skins.values[map['skin']] : Skins.iOS;
    s.theme.value = map['theme'] != null ? ThemeMode.values[map['theme']] : ThemeMode.system;
    s.fullscreenViewerSwipeDir.value = map['fullscreenViewerSwipeDir'] != null
        ? SwipeDirection.values[map['fullscreenViewerSwipeDir']]
        : SwipeDirection.RIGHT;
    s.pinRowsPortrait.value = map['pinRowsPortrait'] ?? 3;
    s.pinColumnsPortrait.value = map['pinColumnsPortrait'] ?? 3;
    s.pinRowsLandscape.value = map['pinRowsLandscape'] ?? 1;
    s.pinColumnsLandscape.value = map['pinColumnsLandscape'] ?? 4;
    s.maxAvatarsInGroupWidget.value = map['maxAvatarsInGroupWidget'] ?? 4;
    s.titleBarStyle.value = map['titleBarStyle'] != null
        ? BBTitleBarStyle.values[map['titleBarStyle']]
        : map['useCustomTitleBar'] == false
            ? BBTitleBarStyle.native
            : BBTitleBarStyle.custom;

    s.showReplyField.value = map['showReplyField'] ?? true;
    s.selectedActionIndices.value = _processSelectedActionIndices(map['selectedActionIndices'], s.showReplyField.value);
    s.actionList.value = _processActionList(map['actionList']);
    s._detailsMenuActions.value = _processDetailsMenuActions(map['detailsMenuActions'], DetailsMenuAction.values);
    s.textFieldButtons.value = _processTextFieldButtons(map['textFieldButtons']);

    s.windowEffect.value = (kIsDesktop && Platform.isWindows)
        ? WindowEffect.values.firstWhereOrNull((e) => e.name == map['windowEffect']) ?? WindowEffect.disabled
        : WindowEffect.disabled;
    s.windowEffectCustomOpacityLight.value = map['windowEffectCustomOpacityLight']?.toDouble() ?? 0.5;
    s.windowEffectCustomOpacityDark.value = map['windowEffectCustomOpacityDark']?.toDouble() ?? 0.5;
    s.desktopNotifications.value = map['desktopNotifications'] ?? true;
    s.desktopNotificationSoundVolume.value = map['desktopNotificationSoundVolume'] ?? 100;
    s.desktopNotificationSoundPath.value = map['desktopNotificationSoundPath'];
    s.useDesktopAccent.value = map['useDesktopAccent'] ?? map['useWindowsAccent'] ?? false;
    s.windowsTaskbarBadge.value = map['windowsTaskbarBadge'] ?? true;
    s.firstFcmRegisterDate.value = map['firstFcmRegisterDate'] ?? 0;
    s.logLevel.value = map['logLevel'] != null ? Level.values[map['logLevel']] : Level.info;
    s.hideNamesForReactions.value = map['hideNamesForReactions'] ?? false;
    s.replaceEmoticonsWithEmoji.value = map['replaceEmoticonsWithEmoji'] ?? false;
    s.lastReviewRequestTimestamp.value = map['lastReviewRequestTimestamp'] ?? 0;
    return s;
  }

  /// function to set detailsMenuActions from a subset of allActions
  void setDetailsMenuActions(List<DetailsMenuAction> actions) {
    SettingsSvc.settings._detailsMenuActions.value =
        _filterDetailsMenuActions(actions, SettingsSvc.settings.detailsMenuActions);
    // saveOneAsync (not save()) so the GlobalIsolate's copy is synced too, else it
    // overwrites this on its next background settings write.
    unawaited(SettingsSvc.settings.saveOneAsync('detailsMenuActions'));
  }

  /// Set the enabled text field buttons, in display order
  void setTextFieldButtons(List<TextFieldButton> buttons) {
    SettingsSvc.settings.textFieldButtons.value = buttons;
    // saveOneAsync (not save()) so the GlobalIsolate's copy is synced too
    unawaited(SettingsSvc.settings.saveOneAsync('textFieldButtons'));
  }

  void resetTextFieldButtons() {
    SettingsSvc.settings.textFieldButtons.value = TextFieldButton.values;
    unawaited(SettingsSvc.settings.saveOneAsync('textFieldButtons'));
  }

  void resetDetailsMenuActions() {
    SettingsSvc.settings._detailsMenuActions.value = DetailsMenuAction.values;
    unawaited(SettingsSvc.settings.saveOneAsync('detailsMenuActions'));
  }
}

Map<String, String> _processCustomHeaders(dynamic rawJson) {
  try {
    return (rawJson is Map ? rawJson : jsonDecode(rawJson) as Map).cast<String, String>();
  } catch (e) {
    debugPrint("Using default customHeaders");
    return <String, String>{};
  }
}

/// Accepts either an already-decoded [Map] (e.g. synced in-memory to the
/// GlobalIsolate) or a JSON-encoded [String] (round-tripped through disk
/// prefs, which only store primitives/strings).
Map<String, String> _processSavedChatFilters(dynamic rawJson) {
  try {
    return (rawJson is Map ? rawJson : jsonDecode(rawJson) as Map).cast<String, String>();
  } catch (e) {
    return <String, String>{};
  }
}

List<int> _processSelectedActionIndices(dynamic rawJson, bool showReplyField) {
  try {
    return (rawJson is List ? rawJson : jsonDecode(rawJson) as List)
        .cast<int>()
        .take(Platform.isWindows ? (showReplyField ? 4 : 5) : 3)
        .sorted(Comparable.compare);
  } catch (e) {
    debugPrint("Using default selectedActionIndices");
    return [0, 1, 2, 3, 4].take(Platform.isWindows ? (showReplyField ? 4 : 5) : 3).sorted(Comparable.compare);
  }
}

List<String> _processActionList(dynamic rawJson) {
  try {
    return (rawJson is List ? rawJson : jsonDecode(rawJson) as List).cast<String>();
  } catch (e) {
    debugPrint("Using default actionList");
    return [
      "Mark Read",
      ReactionTypes.LOVE,
      ReactionTypes.LIKE,
      ReactionTypes.LAUGH,
      ReactionTypes.EMPHASIZE,
      ReactionTypes.DISLIKE,
      ReactionTypes.QUESTION
    ];
  }
}

List<TextFieldButton> _processTextFieldButtons(dynamic rawJson) {
  try {
    return (rawJson is List ? rawJson : jsonDecode(rawJson) as List)
        .cast<String>()
        .map((s) => TextFieldButton.values.firstWhereOrNull((button) => button.name == s))
        .nonNulls
        .toList();
  } catch (e) {
    debugPrint("Using default textFieldButtons");
    return TextFieldButton.values;
  }
}

List<DetailsMenuAction> _processDetailsMenuActions(dynamic rawJson, List<DetailsMenuAction> allActions) {
  try {
    List<DetailsMenuAction> actions = (rawJson is List ? rawJson : jsonDecode(rawJson) as List)
        .cast<String>()
        .map((s) => DetailsMenuAction.values.firstWhereOrNull((action) => action.name == s))
        .nonNulls
        .toList();
    return _filterDetailsMenuActions(actions, allActions);
  } catch (e) {
    debugPrint("Using default detailsMenuActions");
    return DetailsMenuAction.values;
  }
}

List<DetailsMenuAction> _filterDetailsMenuActions(List<DetailsMenuAction> actions, List<DetailsMenuAction> allActions) {
  // Keep existing order of other keys
  List<(DetailsMenuAction, int)> remainingIndexed =
      allActions.mapIndexed((i, action) => (action, i)).whereNot((mapEntry) => actions.contains(mapEntry.$1)).toList();

  for ((DetailsMenuAction, int) item in remainingIndexed) {
    actions.insert(item.$2, item.$1);
  }

  return actions;
}
