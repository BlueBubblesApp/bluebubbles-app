import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/details_menu_action.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:universal_io/io.dart';

class Settings {
  final RxInt firstFcmRegisterDate = 0.obs;
  final RxString iCloudAccount = "".obs;
  final RxString guidAuthKey = "".obs;
  final RxString serverAddress = "".obs;
  final RxMap<String, String> customHeaders = <String, String>{}.obs;
  final RxBool finishedSetup = false.obs;
  final RxBool reachedConversationList = false.obs;
  final RxBool autoDownload = true.obs;
  final RxBool onlyWifiDownload = false.obs;
  final RxBool autoSave = false.obs;
  final RxString autoSavePicsLocation = "Pictures".obs;
  final RxString autoSaveDocsLocation = "/storage/emulated/0/Download/".obs;
  final RxBool autoOpenKeyboard = true.obs;
  final RxBool hideTextPreviews = false.obs;
  final RxBool showIncrementalSync = false.obs;
  final RxBool highPerfMode = false.obs;
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
  final RxBool showConnectionIndicator = false.obs;
  final RxBool showSyncIndicator = true.obs;
  final RxInt sendDelay = 0.obs;
  final RxBool recipientAsPlaceholder = false.obs;
  final RxBool hideKeyboardOnScroll = false.obs;
  final RxBool moveChatCreatorToHeader = false.obs;
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
  final RxString notificationSound = "default".obs;
  final RxBool colorsFromMedia = false.obs;
  final Rx<Monet> monetTheming = Monet.none.obs;
  final RxString globalTextDetection = "".obs;
  final RxBool filterUnknownSenders = false.obs;
  final RxBool tabletMode = true.obs;
  final RxBool highlightSelectedChat = true.obs;
  final RxBool immersiveMode = false.obs;
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
  final RxBool generateFakeContactNames = false.obs;
  final RxBool hideMessageContent = false.obs;

  // Quick tapback settings
  final RxBool enableQuickTapback = false.obs;
  final RxString quickTapbackType = ReactionTypes.toList()[0].obs; // The 'love' reaction

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

  // Troubleshooting settings
  final Rx<Level> logLevel = Level.info.obs;

  // Notification actions
  final RxList<int> selectedActionIndices = Platform.isWindows ? [0, 1, 2, 3, 4].obs : [0, 1, 2].obs;
  final RxList<String> actionList = RxList.from([
    "Mark Read",
    ReactionTypes.LOVE,
    ReactionTypes.LIKE,
    ReactionTypes.LAUGH,
    ReactionTypes.EMPHASIZE,
    ReactionTypes.DISLIKE,
    ReactionTypes.QUESTION
  ]);

  // Message options order
  final RxList<DetailsMenuAction> _detailsMenuActions = RxList.from(DetailsMenuAction.values);

  /// Use [setDetailsMenuActions] to set this value
  List<DetailsMenuAction> get detailsMenuActions => _detailsMenuActions;

  // Linux settings
  final RxBool useCustomTitleBar = RxBool(true);

  // Windows settings
  final RxBool useWindowsAccent = RxBool(false);

  Future<DisplayMode> getDisplayMode() async {
    List<DisplayMode> modes = await FlutterDisplayMode.supported;
    return modes.firstWhereOrNull((element) => element.refreshRate.round() == refreshRate.value) ?? DisplayMode.auto;
  }

  Future<void> _savePref(String key, dynamic value) async {
    if (value is bool) {
      await ss.prefs.setBool(key, value);
    } else if (value is String) {
      await ss.prefs.setString(key, value);
    } else if (value is int) {
      await ss.prefs.setInt(key, value);
    } else if (value is double) {
      await ss.prefs.setDouble(key, value);
    } else if (value is List<DetailsMenuAction>) {
      await ss.prefs.setString(key, jsonEncode(value.map((action) => action.name).toList()));
    } else if (value is List || value is Map) {
      await ss.prefs.setString(key, jsonEncode(value));
    } else if (value == null) {
      await ss.prefs.remove(key);
    }
  }

  Settings save() {
    Map<String, dynamic> map = toMap(includeAll: true);
    map.forEach((key, value) async {
      await _savePref(key, value);
    });
    return this;
  }

  Future<Settings> saveAsync() async {
    Map<String, dynamic> map = toMap(includeAll: true);
    // Wait for each key to be saved before moving on
    await Future.forEach(map.entries, (entry) async {
      await _savePref(entry.key, entry.value);
    });

    return this;
  }

  Future<Settings> saveOne(String key) async {
    Map<String, dynamic> map = toMap(includeAll: true);
    if (map.containsKey(key)) {
      await _savePref(key, map[key]);
    }

    return this;
  }

  Future<Settings> saveMany(List<String> keys) async {
    Map<String, dynamic> map = toMap(includeAll: true);
    for (String key in keys) {
      if (map.containsKey(key)) {
        await _savePref(key, map[key]);
      }
    }

    return this;
  }

  static Settings getSettings() {
    Set<String> keys = ss.prefs.getKeys();

    Map<String, dynamic> items = {};
    for (String s in keys) {
      items[s] = ss.prefs.get(s);
    }
    if (items.isNotEmpty) {
      return Settings.fromMap(items);
    } else {
      return Settings();
    }
  }

  Map<String, dynamic> toMap({bool includeAll = false}) {
    Map<String, dynamic> map = {
      'autoDownload': autoDownload.value,
      'onlyWifiDownload': onlyWifiDownload.value,
      'autoSave': autoSave.value,
      'autoSavePicsLocation': autoSavePicsLocation.value,
      'autoSaveDocsLocation': autoSaveDocsLocation.value,
      'autoOpenKeyboard': autoOpenKeyboard.value,
      'hideTextPreviews': hideTextPreviews.value,
      'showIncrementalSync': showIncrementalSync.value,
      'highPerfMode': highPerfMode.value,
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
      'showConnectionIndicator': showConnectionIndicator.value,
      'showSyncIndicator': showSyncIndicator.value,
      'sendDelay': sendDelay.value,
      'recipientAsPlaceholder': recipientAsPlaceholder.value,
      'hideKeyboardOnScroll': hideKeyboardOnScroll.value,
      'moveChatCreatorToHeader': moveChatCreatorToHeader.value,
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
      'notificationSound': notificationSound.value,
      'globalTextDetection': globalTextDetection.value,
      'filterUnknownSenders': filterUnknownSenders.value,
      'tabletMode': tabletMode.value,
      'immersiveMode': immersiveMode.value,
      'avatarScale': avatarScale.value,
      'launchAtStartup': launchAtStartup.value,
      'launchAtStartupMinimized': launchAtStartupMinimized.value,
      'closeToTray': closeToTray.value,
      'spellcheck': spellcheck.value,
      'spellcheckLanguage': spellcheckLanguage.value,
      'minimizeToTray': minimizeToTray.value,
      'selectedActionIndices': selectedActionIndices,
      'actionList': actionList,
      'detailsMenuActions': detailsMenuActions.map((action) => action.name).toList(),
      'askWhereToSave': askWhereToSave.value,
      'indicatorsOnPinnedChats': statusIndicatorsOnChats.value,
      'apiTimeout': apiTimeout.value,
      'allowUpsideDownRotation': allowUpsideDownRotation.value,
      'cancelQueuedMessages': cancelQueuedMessages.value,
      'repliesToPrevious': repliesToPrevious.value,
      'useLocalhost': localhostPort.value,
      'useLocalIpv6': useLocalIpv6.value,
      'sendSoundPath': sendSoundPath.value,
      'receiveSoundPath': receiveSoundPath.value,
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
      'generateFakeContactNames': generateFakeContactNames.value,
      'generateFakeMessageContent': hideMessageContent.value,
      'enableQuickTapback': enableQuickTapback.value,
      'quickTapbackType': quickTapbackType.value,
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
      'useCustomTitleBar': useCustomTitleBar.value,
      'windowEffect': windowEffect.value.name,
      'windowEffectCustomOpacityLight': windowEffectCustomOpacityLight.value,
      'windowEffectCustomOpacityDark': windowEffectCustomOpacityDark.value,
      'useWindowsAccent': useWindowsAccent.value,
      'logLevel': logLevel.value.index,
      'hideNamesForReactions': hideNamesForReactions.value,
      'lastReviewRequestTimestamp': lastReviewRequestTimestamp.value,
    };
    if (includeAll) {
      map.addAll({
        'iCloudAccount': iCloudAccount.value,
        'guidAuthKey': guidAuthKey.value,
        'serverAddress': serverAddress.value,
        'customHeaders': customHeaders,
        'finishedSetup': finishedSetup.value,
        'reachedConversationList': reachedConversationList.value,
        'colorsFromMedia': colorsFromMedia.value,
        'monetTheming': monetTheming.value.index,
        'userAvatarPath': userAvatarPath.value,
        'firstFcmRegisterDate': firstFcmRegisterDate.value,
      });
    }
    return map;
  }

  static void updateFromMap(Map<String, dynamic> map) {
    ss.settings.autoDownload.value = map['autoDownload'] ?? true;
    ss.settings.onlyWifiDownload.value = map['onlyWifiDownload'] ?? false;
    ss.settings.autoSave.value = map['autoSave'] ?? false;
    ss.settings.autoSavePicsLocation.value = map['autoSavePicsLocation'] ?? "Pictures";
    ss.settings.autoSaveDocsLocation.value = map['autoSaveDocsLocation'] ?? "/storage/emulated/0/Download/";
    ss.settings.autoOpenKeyboard.value = map['autoOpenKeyboard'] ?? true;
    ss.settings.hideTextPreviews.value = map['hideTextPreviews'] ?? false;
    ss.settings.showIncrementalSync.value = map['showIncrementalSync'] ?? false;
    ss.settings.highPerfMode.value = map['highPerfMode'] ?? false;
    ss.settings.refreshRate.value = map['refreshRate'] ?? 0;
    ss.settings.colorfulAvatars.value = map['colorfulAvatars'] ?? false;
    ss.settings.colorfulBubbles.value = map['colorfulBubbles'] ?? false;
    ss.settings.hideDividers.value = map['hideDividers'] ?? false;
    ss.settings.scrollVelocity.value = map['scrollVelocity']?.toDouble() ?? 1;
    ss.settings.sendWithReturn.value = map['sendWithReturn'] ?? false;
    ss.settings.doubleTapForDetails.value = map['doubleTapForDetails'] ?? false;
    ss.settings.denseChatTiles.value = map['denseChatTiles'] ?? false;
    ss.settings.smartReply.value = map['smartReply'] ?? false;
    ss.settings.showConnectionIndicator.value = map['showConnectionIndicator'] ?? false;
    ss.settings.showSyncIndicator.value = map['showSyncIndicator'] ?? true;
    ss.settings.sendDelay.value = map['sendDelay'] ?? 0;
    ss.settings.recipientAsPlaceholder.value = map['recipientAsPlaceholder'] ?? false;
    ss.settings.hideKeyboardOnScroll.value = map['hideKeyboardOnScroll'] ?? false;
    ss.settings.moveChatCreatorToHeader.value = map['moveChatCreatorToHeader'] ?? false;
    ss.settings.cameraFAB.value = map['cameraFAB'] ?? false;
    ss.settings.swipeToCloseKeyboard.value = map['swipeToCloseKeyboard'] ?? false;
    ss.settings.swipeToOpenKeyboard.value = map['swipeToOpenKeyboard'] ?? false;
    ss.settings.openKeyboardOnSTB.value = map['openKeyboardOnSTB'] ?? false;
    ss.settings.swipableConversationTiles.value = map['swipableConversationTiles'] ?? false;
    ss.settings.showDeliveryTimestamps.value = map['showDeliveryTimestamps'] ?? false;
    ss.settings.filteredChatList.value = map['filteredChatList'] ?? false;
    ss.settings.startVideosMuted.value = map['startVideosMuted'] ?? true;
    ss.settings.startVideosMutedFullscreen.value = map['startVideosMutedFullscreen'] ?? true;
    ss.settings.use24HrFormat.value = map['use24HrFormat'] ?? false;
    ss.settings.alwaysShowAvatars.value = map['alwaysShowAvatars'] ?? false;
    ss.settings.notifyOnChatList.value = map['notifyOnChatList'] ?? false;
    ss.settings.notifyReactions.value = map['notifyReactions'] ?? true;
    ss.settings.notificationSound.value = map['notificationSound'] ?? "default";
    ss.settings.globalTextDetection.value = map['globalTextDetection'] ?? "";
    ss.settings.filterUnknownSenders.value = map['filterUnknownSenders'] ?? false;
    ss.settings.tabletMode.value = kIsDesktop || (map['tabletMode'] ?? true);
    ss.settings.immersiveMode.value = map['immersiveMode'] ?? false;
    ss.settings.avatarScale.value = map['avatarScale']?.toDouble() ?? 1.0;
    ss.settings.launchAtStartup.value = map['launchAtStartup'] ?? false;
    ss.settings.launchAtStartupMinimized.value = map['launchAtStartupMinimized'] ?? false;
    ss.settings.closeToTray.value = map['closeToTray'] ?? true;
    ss.settings.spellcheck.value = map['spellcheck'] ?? true;
    ss.settings.spellcheckLanguage.value = map['spellcheckLanguage'] ?? 'auto';
    ss.settings.minimizeToTray.value = map['minimizeToTray'] ?? false;
    ss.settings.askWhereToSave.value = map['askWhereToSave'] ?? false;
    ss.settings.statusIndicatorsOnChats.value = map['indicatorsOnPinnedChats'] ?? false;
    ss.settings.apiTimeout.value = map['apiTimeout'] ?? 15000;
    ss.settings.allowUpsideDownRotation.value = map['allowUpsideDownRotation'] ?? false;
    ss.settings.cancelQueuedMessages.value = map['cancelQueuedMessages'] ?? false;
    ss.settings.repliesToPrevious.value = map['repliesToPrevious'] ?? false;
    ss.settings.localhostPort.value = map['useLocalhost'];
    ss.settings.useLocalIpv6.value = map['useLocalIpv6'] ?? false;
    ss.settings.sendSoundPath.value = map['sendSoundPath'];
    ss.settings.receiveSoundPath.value = map['receiveSoundPath'];
    ss.settings.soundVolume.value = map['soundVolume'] ?? 100;
    ss.settings.syncContactsAutomatically.value = map['syncContactsAutomatically'] ?? false;
    ss.settings.scrollToBottomOnSend.value = map['scrollToBottomOnSend'] ?? true;
    ss.settings.sendEventsToTasker.value = map['sendEventsToTasker'] ?? true;
    ss.settings.keepAppAlive.value = map['keepAppAlive'] ?? false;
    ss.settings.unarchiveOnNewMessage.value = map['unarchiveOnNewMessage'] ?? false;
    ss.settings.scrollToLastUnread.value = map['scrollToLastUnread'] ?? false;
    ss.settings.userName.value = map['userName'] ?? "You";
    ss.settings.privateAPISend.value = map['privateAPISend'] ?? false;
    ss.settings.privateAPIAttachmentSend.value = map['privateAPIAttachmentSend'] ?? false;
    ss.settings.enablePrivateAPI.value = map['enablePrivateAPI'] ?? false;
    ss.settings.privateSendTypingIndicators.value = map['privateSendTypingIndicators'] ?? false;
    ss.settings.privateMarkChatAsRead.value = map['privateMarkChatAsRead'] ?? false;
    ss.settings.privateManualMarkAsRead.value = map['privateManualMarkAsRead'] ?? false;
    ss.settings.privateSubjectLine.value = map['privateSubjectLine'] ?? false;
    ss.settings.editLastSentMessageOnUpArrow.value = map['editLastSentMessageOnUpArrow'] ?? false;
    ss.settings.redactedMode.value = map['redactedMode'] ?? false;
    ss.settings.hideMessageContent.value = map['hideMessageContent'] ?? true;
    ss.settings.hideAttachments.value = map['hideAttachments'] ?? true;
    ss.settings.hideContactInfo.value = map['hideContactInfo'] ?? true;
    ss.settings.generateFakeContactNames.value = map['generateFakeContactNames'] ?? false;
    ss.settings.hideMessageContent.value = map['generateFakeMessageContent'] ?? false;
    ss.settings.enableQuickTapback.value = map['enableQuickTapback'] ?? false;
    ss.settings.quickTapbackType.value = map['quickTapbackType'] ?? ReactionTypes.toList()[0];
    ss.settings.materialRightAction.value = map['materialRightAction'] != null
        ? MaterialSwipeAction.values[map['materialRightAction']]
        : MaterialSwipeAction.pin;
    ss.settings.materialLeftAction.value = map['materialLeftAction'] != null
        ? MaterialSwipeAction.values[map['materialLeftAction']]
        : MaterialSwipeAction.archive;
    ss.settings.shouldSecure.value = map['shouldSecure'] ?? false;
    ss.settings.securityLevel.value =
        map['securityLevel'] != null ? SecurityLevel.values[map['securityLevel']] : SecurityLevel.locked;
    ss.settings.incognitoKeyboard.value = map['incognitoKeyboard'] ?? false;
    ss.settings.skin.value = map['skin'] != null ? Skins.values[map['skin']] : Skins.iOS;
    ss.settings.theme.value = map['theme'] != null ? ThemeMode.values[map['theme']] : ThemeMode.system;
    ss.settings.fullscreenViewerSwipeDir.value = map['fullscreenViewerSwipeDir'] != null
        ? SwipeDirection.values[map['fullscreenViewerSwipeDir']]
        : SwipeDirection.RIGHT;
    ss.settings.pinRowsPortrait.value = map['pinRowsPortrait'] ?? 3;
    ss.settings.pinColumnsPortrait.value = map['pinColumnsPortrait'] ?? 3;
    ss.settings.pinRowsLandscape.value = map['pinRowsLandscape'] ?? 1;
    ss.settings.pinColumnsLandscape.value = map['pinColumnsLandscape'] ?? 4;
    ss.settings.maxAvatarsInGroupWidget.value = map['maxAvatarsInGroupWidget'] ?? 4;
    ss.settings.useCustomTitleBar.value = map['useCustomTitleBar'] ?? true;

    ss.settings.selectedActionIndices.value = _processSelectedActionIndices(map['selectedActionIndices']);
    ss.settings.actionList.value = _processActionList(map['actionList']);
    ss.settings._detailsMenuActions.value = _processDetailsMenuActions(map['detailsMenuActions'], ss.settings.detailsMenuActions);

    ss.settings.windowEffect.value = kIsDesktop && Platform.isWindows
        ? WindowEffect.values.firstWhereOrNull((e) => e.name == map['windowEffect']) ?? WindowEffect.disabled
        : WindowEffect.disabled;
    ss.settings.windowEffectCustomOpacityLight.value = map['windowEffectCustomOpacityLight']?.toDouble() ?? 0.5;
    ss.settings.windowEffectCustomOpacityDark.value = map['windowEffectCustomOpacityDark']?.toDouble() ?? 0.5;
    ss.settings.useWindowsAccent.value = map['useWindowsAccent'] ?? false;
    ss.settings.firstFcmRegisterDate.value = map['firstFcmRegisterDate'] ?? 0;
    ss.settings.logLevel.value = map['logLevel'] != null ? Level.values[map['logLevel']] : Level.info;
    ss.settings.hideNamesForReactions.value = map['hideNamesForReactions'] ?? false;
    ss.settings.save();

    eventDispatcher.emit("theme-update", null);
  }

  static Settings fromMap(Map<String, dynamic> map) {
    Settings s = Settings();
    s.iCloudAccount.value = map['iCloudAccount'] ?? "";
    s.guidAuthKey.value = map['guidAuthKey'] ?? "";
    s.serverAddress.value = map['serverAddress'] ?? "";
    s.customHeaders.value = _processCustomHeaders(map['customHeaders']);
    s.finishedSetup.value = map['finishedSetup'] ?? false;
    s.autoDownload.value = map['autoDownload'] ?? true;
    s.autoSave.value = map['autoSave'] ?? false;
    s.autoSavePicsLocation.value = map['autoSavePicsLocation'] ?? "Pictures";
    s.autoSaveDocsLocation.value = map['autoSaveDocsLocation'] ?? "/storage/emulated/0/Download/";
    s.onlyWifiDownload.value = map['onlyWifiDownload'] ?? false;
    s.autoOpenKeyboard.value = map['autoOpenKeyboard'] ?? true;
    s.hideTextPreviews.value = map['hideTextPreviews'] ?? false;
    s.showIncrementalSync.value = map['showIncrementalSync'] ?? false;
    s.highPerfMode.value = map['highPerfMode'] ?? false;
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
    s.showConnectionIndicator.value = map['showConnectionIndicator'] ?? false;
    s.showSyncIndicator.value = map['showSyncIndicator'] ?? true;
    s.sendDelay.value = map['sendDelay'] ?? 0;
    s.recipientAsPlaceholder.value = map['recipientAsPlaceholder'] ?? false;
    s.hideKeyboardOnScroll.value = map['hideKeyboardOnScroll'] ?? false;
    s.moveChatCreatorToHeader.value = map['moveChatCreatorToHeader'] ?? false;
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
    s.notificationSound.value = map['notificationSound'] ?? "default";
    s.colorsFromMedia.value = map['colorsFromMedia'] ?? false;
    s.monetTheming.value = map['monetTheming'] != null ? Monet.values[map['monetTheming']] : Monet.none;
    s.globalTextDetection.value = map['globalTextDetection'] ?? "";
    s.filterUnknownSenders.value = map['filterUnknownSenders'] ?? false;
    s.tabletMode.value = kIsDesktop || (map['tabletMode'] ?? true);
    s.highlightSelectedChat.value = map['highlightSelectedChat'] ?? true;
    s.immersiveMode.value = map['immersiveMode'] ?? false;
    s.avatarScale.value = map['avatarScale']?.toDouble() ?? 1.0;
    s.launchAtStartup.value = map['launchAtStartup'] ?? false;
    s.launchAtStartupMinimized.value = map['launchAtStartupMinimized'] ?? false;
    s.closeToTray.value = map['closeToTray'] ?? true;
    s.spellcheck.value = map['spellcheck'] ?? true;
    s.spellcheckLanguage.value = map['spellcheckLanguage'] ?? 'auto';
    s.minimizeToTray.value = map['minimizeToTray'] ?? false;
    s.askWhereToSave.value = map['askWhereToSave'] ?? false;
    s.statusIndicatorsOnChats.value = map['indicatorsOnPinnedChats'] ?? false;
    s.apiTimeout.value = map['apiTimeout'] ?? 15000;
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
    s.privateSendTypingIndicators.value = map['privateSendTypingIndicators'] ?? false;
    s.privateMarkChatAsRead.value = map['privateMarkChatAsRead'] ?? false;
    s.privateManualMarkAsRead.value = map['privateManualMarkAsRead'] ?? false;
    s.privateSubjectLine.value = map['privateSubjectLine'] ?? false;
    s.editLastSentMessageOnUpArrow.value = map['editLastSentMessageOnUpArrow'] ?? false;
    s.redactedMode.value = map['redactedMode'] ?? false;
    s.hideMessageContent.value = map['hideMessageContent'] ?? true;
    s.hideAttachments.value = map['hideAttachments'] ?? true;
    s.hideContactInfo.value = map['hideContactInfo'] ?? true;
    s.generateFakeContactNames.value = map['generateFakeContactNames'] ?? false;
    s.hideMessageContent.value = map['generateFakeMessageContent'] ?? false;
    s.enableQuickTapback.value = map['enableQuickTapback'] ?? false;
    s.quickTapbackType.value = map['quickTapbackType'] ?? ReactionTypes.toList()[0];
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
    s.useCustomTitleBar.value = map['useCustomTitleBar'] ?? true;

    s.selectedActionIndices.value = _processSelectedActionIndices(map['selectedActionIndices']);
    s.actionList.value = _processActionList(map['actionList']);
    s._detailsMenuActions.value = _processDetailsMenuActions(map['detailsMenuActions'], DetailsMenuAction.values);

    s.windowEffect.value = (kIsDesktop && Platform.isWindows)
        ? WindowEffect.values.firstWhereOrNull((e) => e.name == map['windowEffect']) ?? WindowEffect.disabled
        : WindowEffect.disabled;
    s.windowEffectCustomOpacityLight.value = map['windowEffectCustomOpacityLight']?.toDouble() ?? 0.5;
    s.windowEffectCustomOpacityDark.value = map['windowEffectCustomOpacityDark']?.toDouble() ?? 0.5;
    s.useWindowsAccent.value = map['useWindowsAccent'] ?? false;
    s.firstFcmRegisterDate.value = map['firstFcmRegisterDate'] ?? 0;
    s.logLevel.value = map['logLevel'] != null ? Level.values[map['logLevel']] : Level.info;
    s.hideNamesForReactions.value = map['hideNamesForReactions'] ?? false;
    s.lastReviewRequestTimestamp.value = map['lastReviewRequestTimestamp'] ?? 0;
    return s;
  }

  /// function to set detailsMenuActions from a subset of allActions
  void setDetailsMenuActions(List<DetailsMenuAction> actions) {
    ss.settings._detailsMenuActions.value = _filterDetailsMenuActions(actions, ss.settings.detailsMenuActions);
    ss.settings.save();
  }

  void resetDetailsMenuActions() {
    ss.settings._detailsMenuActions.value = DetailsMenuAction.values;
    ss.settings.save();
  }
}

Map<String, String> _processCustomHeaders(dynamic rawJson) {
  try {
    return (rawJson is Map ? rawJson : jsonDecode(rawJson) as Map).cast<String, String>();
  } catch (e) {
    debugPrint("Using default customHeaders");
    return {};
  }
}

List<int> _processSelectedActionIndices(dynamic rawJson) {
  try {
    return (rawJson is List ? rawJson : jsonDecode(rawJson) as List).cast<int>().take(Platform.isWindows ? 5 : 3).toList();
  } catch (e) {
    debugPrint("Using default selectedActionIndices");
    return [0, 1, 2, 3, 4].take(Platform.isWindows ? 5 : 3).toList();
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

List<DetailsMenuAction> _processDetailsMenuActions(dynamic rawJson, List<DetailsMenuAction> allActions) {
  try {
    List<DetailsMenuAction> actions = (rawJson is List ? rawJson : jsonDecode(rawJson) as List)
        .cast<String>()
        .map((s) => DetailsMenuAction.values.firstWhereOrNull((action) => action.name == s))
        .whereNotNull()
        .toList();
    return _filterDetailsMenuActions(actions, allActions);
  } catch (e) {
    debugPrint("Using default detailsMenuActions");
    return DetailsMenuAction.values;
  }
}

List<DetailsMenuAction> _filterDetailsMenuActions(List<DetailsMenuAction> actions, List<DetailsMenuAction> allActions) {
  // Keep existing order of other keys
  List<(DetailsMenuAction, int)> remainingIndexed = allActions.mapIndexed((i, action) => (action, i)).whereNot((mapEntry) => actions.contains(mapEntry.$1)).toList();

  for ((DetailsMenuAction, int) item in remainingIndexed) {
    actions.insert(item.$2, item.$1);
  }

  return actions;
}
