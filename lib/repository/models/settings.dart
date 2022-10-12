import 'dart:async';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/repository/models/config_entry.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';

class Settings {
  final RxString guidAuthKey = "".obs;
  final RxString serverAddress = "".obs;
  final RxBool finishedSetup = false.obs;
  final RxBool autoDownload = true.obs;
  final RxBool onlyWifiDownload = false.obs;
  final RxBool autoSave = false.obs;
  final RxBool autoOpenKeyboard = true.obs;
  final RxBool hideTextPreviews = false.obs;
  final RxBool showIncrementalSync = false.obs;
  final RxBool lowMemoryMode = false.obs;
  final RxInt lastIncrementalSync = 0.obs;
  final RxInt refreshRate = 0.obs;
  final RxBool colorfulAvatars = false.obs;
  final RxBool colorfulBubbles = false.obs;
  final RxBool hideDividers = false.obs;
  final RxDouble scrollVelocity = 1.00.obs;
  final RxBool sendWithReturn = false.obs;
  final RxBool doubleTapForDetails = false.obs;
  final RxBool denseChatTiles = false.obs;
  final RxBool smartReply = false.obs;
  final RxBool reducedForehead = false.obs;
  final RxBool preCachePreviewImages = true.obs;
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
  final RxBool colorblindMode = false.obs;
  final RxBool showDeliveryTimestamps = false.obs;
  final RxInt previewCompressionQuality = 50.obs;
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
  final RxInt apiTimeout = 15000.obs;
  final RxBool allowUpsideDownRotation = false.obs;
  // final RxString emojiFontFamily;

  // Private API features
  final RxBool enablePrivateAPI = false.obs;
  final RxBool privateSendTypingIndicators = false.obs;
  final RxBool privateMarkChatAsRead = false.obs;
  final RxBool privateManualMarkAsRead = false.obs;
  final RxBool privateSubjectLine = false.obs;
  final RxBool swipeToReply = false.obs;
  final RxBool privateAPISend = false.obs;

  // Redacted Mode Settings
  final RxBool redactedMode = false.obs;
  final RxBool hideMessageContent = true.obs;
  final RxBool hideReactions = false.obs;
  final RxBool hideAttachments = true.obs;
  final RxBool hideEmojis = false.obs;
  final RxBool hideAttachmentTypes = false.obs;
  final RxBool hideContactPhotos = true.obs;
  final RxBool hideContactInfo = true.obs;
  final RxBool removeLetterAvatars = true.obs;
  final RxBool generateFakeContactNames = false.obs;
  final RxBool generateFakeMessageContent = false.obs;

  // Quick tapback settings
  final RxBool enableQuickTapback = false.obs;
  final RxString quickTapbackType = ReactionTypes.toList()[0].obs; // The 'love' reaction

  // Slideable action settings
  final RxBool iosShowPin = RxBool(true);
  final RxBool iosShowAlert = RxBool(true);
  final RxBool iosShowDelete = RxBool(true);
  final RxBool iosShowMarkRead = RxBool(true);
  final RxBool iosShowArchive = RxBool(true);
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
  final RxInt pinColumnsLandscape = RxInt(6);

  final RxInt maxAvatarsInGroupWidget = RxInt(4);

  // Desktop settings
  final RxBool launchAtStartup = false.obs;
  final RxBool minimizeToTray = false.obs;
  final RxBool closeToTray = true.obs;
  final Rx<WindowEffect> windowEffect = WindowEffect.disabled.obs;
  final RxDouble windowEffectCustomOpacityLight = 0.5.obs;
  final RxDouble windowEffectCustomOpacityDark = 0.5.obs;

  // Scrolling
  final RxBool betterScrolling = false.obs;
  final RxDouble betterScrollingMultiplier = 7.0.obs;

  // Notification actions
  final RxList<int> selectedActionIndices = [0, 1, 2, 3, 4].obs;
  final RxList<String> actionList = RxList.from(["Mark Read", ReactionTypes.LOVE, ReactionTypes.LIKE, ReactionTypes.LAUGH, ReactionTypes.EMPHASIZE, ReactionTypes.DISLIKE, ReactionTypes.QUESTION]);

  // Linux settings
  final RxBool useCustomTitleBar = RxBool(true);

  // Windows settings
  final RxBool useWindowsAccent = RxBool(false);

  Settings();

  factory Settings.fromConfigEntries(List<ConfigEntry> entries) {
    Settings settings = Settings();
    for (ConfigEntry entry in entries) {
      if (entry.name == "serverAddress") {
        settings.serverAddress.value = entry.value;
      } else if (entry.name == "guidAuthKey") {
        settings.guidAuthKey.value = entry.value;
      } else if (entry.name == "finishedSetup") {
        settings.finishedSetup.value = entry.value;
      } else if (entry.name == "autoOpenKeyboard") {
        settings.autoOpenKeyboard.value = entry.value;
      } else if (entry.name == "autoDownload") {
        settings.autoDownload.value = entry.value;
      } else if (entry.name == "onlyWifiDownload") {
        settings.onlyWifiDownload.value = entry.value;
      } else if (entry.name == "autoSave") {
        settings.autoSave.value = entry.value;
      } else if (entry.name == "hideTextPreviews") {
        settings.hideTextPreviews.value = entry.value;
      } else if (entry.name == "showIncrementalSync") {
        settings.showIncrementalSync.value = entry.value;
      } else if (entry.name == "lowMemoryMode") {
        settings.lowMemoryMode.value = entry.value;
      } else if (entry.name == "lastIncrementalSync") {
        settings.lastIncrementalSync.value = entry.value;
      } else if (entry.name == "displayMode") {
        settings.refreshRate.value = entry.value;
      } else if (entry.name == "rainbowBubbles") {
        settings.colorfulAvatars.value = entry.value;
      } else if (entry.name == "colorfulBubbles") {
        settings.colorfulBubbles.value = entry.value;
      } else if (entry.name == "hideDividers") {
        settings.hideDividers.value = entry.value;
      } else if (entry.name == "theme") {
        settings.theme.value = ThemeMode.values[entry.value];
      } else if (entry.name == "skin") {
        settings.skin.value = Skins.values[entry.value];
      } else if (entry.name == "fullscreenViewerSwipeDir") {
        settings.fullscreenViewerSwipeDir.value = SwipeDirection.values[entry.value];
      } else if (entry.name == "scrollVelocity") {
        settings.scrollVelocity.value = entry.value;
      } else if (entry.name == "sendWithReturn") {
        settings.sendWithReturn.value = entry.value;
      } else if (entry.name == "doubleTapForDetails") {
        settings.doubleTapForDetails.value = entry.value;
      } else if (entry.name == "denseChatTiles") {
        settings.denseChatTiles.value = entry.value;
      } else if (entry.name == "smartReply") {
        settings.smartReply.value = entry.value;
      } else if (entry.name == "reducedForehead") {
        settings.reducedForehead.value = entry.value;
      } else if (entry.name == "preCachePreviewImages") {
        settings.preCachePreviewImages.value = entry.value;
      } else if (entry.name == "showConnectionIndicator") {
        settings.showConnectionIndicator.value = entry.value;
      } else if (entry.name == "sendDelay") {
        settings.sendDelay.value = entry.value;
      } else if (entry.name == "recipientAsPlaceholder") {
        settings.recipientAsPlaceholder.value = entry.value;
      } else if (entry.name == "hideKeyboardOnScroll") {
        settings.hideKeyboardOnScroll.value = entry.value;
      } else if (entry.name == "swipeToOpenKeyboard") {
        settings.swipeToOpenKeyboard.value = entry.value;
      } else if (entry.name == "newMessageMenuBar") {
        settings.moveChatCreatorToHeader.value = entry.value;
      } else if (entry.name == "swipeToCloseKeyboard") {
        settings.swipeToCloseKeyboard.value = entry.value;
      } else if (entry.name == "moveChatCreatorToHeader") {
        settings.moveChatCreatorToHeader.value = entry.value;
      } else if (entry.name == "cameraFAB") {
        settings.cameraFAB.value = entry.value;
      } else if (entry.name == "openKeyboardOnSTB") {
        settings.openKeyboardOnSTB.value = entry.value;
      } else if (entry.name == "swipableConversationTiles") {
        settings.swipableConversationTiles.value = entry.value;
      } else if (entry.name == "enablePrivateAPI") {
        settings.enablePrivateAPI.value = entry.value;
      } else if (entry.name == "privateSendTypingIndicators") {
        settings.privateSendTypingIndicators.value = entry.value;
      } else if (entry.name == "colorblindMode") {
        settings.colorblindMode.value = entry.value;
      } else if (entry.name == "privateMarkChatAsRead") {
        settings.privateMarkChatAsRead.value = entry.value;
      } else if (entry.name == "privateManualMarkAsRead") {
        settings.privateManualMarkAsRead.value = entry.value;
      } else if (entry.name == "privateSubjectLine") {
        settings.privateSubjectLine.value = entry.value;
      } else if (entry.name == "showSyncIndicator") {
        settings.showSyncIndicator.value = entry.value;
      } else if (entry.name == "showDeliveryTimestamps") {
        settings.showDeliveryTimestamps.value = entry.value;
      } else if (entry.name == "redactedMode") {
        settings.redactedMode.value = entry.value;
      } else if (entry.name == "hideMessageContent") {
        settings.hideMessageContent.value = entry.value;
      } else if (entry.name == "hideReactions") {
        settings.hideReactions.value = entry.value;
      } else if (entry.name == "hideAttachments") {
        settings.hideAttachments.value = entry.value;
      } else if (entry.name == "hideAttachmentTypes") {
        settings.hideAttachmentTypes.value = entry.value;
      } else if (entry.name == "hideContactPhotos") {
        settings.hideContactPhotos.value = entry.value;
      } else if (entry.name == "hideContactInfo") {
        settings.hideContactInfo.value = entry.value;
      } else if (entry.name == "removeLetterAvatars") {
        settings.removeLetterAvatars.value = entry.value;
      } else if (entry.name == "generateFakeContactNames") {
        settings.generateFakeContactNames.value = entry.value;
      } else if (entry.name == "generateFakeMessageContent") {
        settings.generateFakeMessageContent.value = entry.value;
      } else if (entry.name == "previewCompressionQuality") {
        settings.previewCompressionQuality.value = entry.value;
      } else if (entry.name == "filteredChatList") {
        settings.filteredChatList.value = entry.value;
      } else if (entry.name == "startVideosMuted") {
        settings.startVideosMuted.value = entry.value;
      } else if (entry.name == "startVideosMutedFullscreen") {
        settings.startVideosMutedFullscreen.value = entry.value;
      } else if (entry.name == "use24HrFormat") {
        settings.use24HrFormat.value = entry.value;
      } else if (entry.name == "enableQuickTapback") {
        settings.enableQuickTapback.value = entry.value;
      } else if (entry.name == "quickTapbackType") {
        settings.quickTapbackType.value = entry.value;
      } else if (entry.name == "alwaysShowAvatars") {
        settings.alwaysShowAvatars.value = entry.value;
      } else if (entry.name == "iosShowPin") {
        settings.iosShowPin.value = entry.value;
      } else if (entry.name == "iosShowAlert") {
        settings.iosShowAlert.value = entry.value;
      } else if (entry.name == "iosShowDelete") {
        settings.iosShowDelete.value = entry.value;
      } else if (entry.name == "iosShowMarkRead") {
        settings.iosShowMarkRead.value = entry.value;
      } else if (entry.name == "iosShowArchive") {
        settings.iosShowArchive.value = entry.value;
      } else if (entry.name == "materialRightAction") {
        settings.materialRightAction.value = MaterialSwipeAction.values[entry.value];
      } else if (entry.name == "materialLeftAction") {
        settings.materialLeftAction.value = MaterialSwipeAction.values[entry.value];
      } else if (entry.name == "shouldSecure") {
        settings.shouldSecure.value = entry.value;
      } else if (entry.name == "securityLevel") {
        settings.securityLevel.value = SecurityLevel.values[entry.value];
      } else if (entry.name == "incognitoKeyboard") {
        settings.incognitoKeyboard.value = entry.value;
      } else if (entry.name == "pinRowsPortrait") {
        settings.pinRowsPortrait.value = entry.value;
      } else if (entry.name == "maxAvatarsInGroupWidget") {
        settings.maxAvatarsInGroupWidget.value = entry.value;
      } else if (entry.name == "notifyOnChatList") {
        settings.notifyOnChatList.value = entry.value;
      } else if (entry.name == "notifyReactions") {
        settings.notifyReactions.value = entry.value;
      } else if (entry.name == "notificationSound") {
        settings.notificationSound.value = entry.value;
      } else if (entry.name == "colorsFromMedia") {
        settings.colorsFromMedia.value = entry.value;
      } else if (entry.name == "monetTheming") {
        settings.monetTheming.value = Monet.values[entry.value];
      } else if (entry.name == "globalTextDetection") {
        settings.globalTextDetection.value = entry.value;
      } else if (entry.name == "filterUnknownSenders") {
        settings.filterUnknownSenders.value = entry.value;
      } else if (entry.name == "tabletMode") {
        settings.tabletMode.value = kIsDesktop || entry.value;
      } else if (entry.name == "immersiveMode") {
        settings.immersiveMode.value = entry.value;
      } else if (entry.name == "swipeToReply") {
        settings.swipeToReply.value = entry.value;
      } else if (entry.name == "privateAPISend") {
        settings.privateAPISend.value = entry.value;
      } else if (entry.name == "avatarScale") {
        settings.avatarScale.value = entry.value;
      } else if (entry.name == "launchAtStartup") {
        settings.launchAtStartup.value = entry.value;
      } else if (entry.name == "minimizeToTray") {
        settings.minimizeToTray.value = entry.value;
      } else if (entry.name == "closeToTray") {
        settings.closeToTray.value = entry.value;
      } else if (entry.name == "selectedActionIndices") {
        settings.selectedActionIndices.value = entry.value;
      } else if (entry.name == "actionList") {
        settings.actionList.value = entry.value;
      } else if (entry.name == "askWhereToSave") {
        settings.askWhereToSave.value = entry.value;
      } else if (entry.name == "indicatorsOnPinnedChats") {
        settings.statusIndicatorsOnChats.value = entry.value;
      } else if (entry.name == "apiTimeout") {
        settings.apiTimeout.value = entry.value;
      } else if (entry.name == "allowUpsideDownRotation") {
        settings.allowUpsideDownRotation.value = entry.value;
      } else if (entry.name == "useCustomTitleBar") {
        settings.useCustomTitleBar.value = entry.value;
      } else if (entry.name == "betterScrolling") {
        settings.betterScrolling.value = entry.value;
      } else if (entry.name == "betterScrollingMultiplier") {
        settings.betterScrollingMultiplier.value = entry.value;
      } else if (entry.name == "windowEffect") {
        settings.windowEffect.value = WindowEffect.values.firstWhereOrNull((e) => e.name == entry.value) ?? WindowEffect.disabled;
      } else if (entry.name == "windowEffectCustomOpacityLight") {
        settings.windowEffectCustomOpacityLight.value = entry.value;
      } else if (entry.name == "windowEffectCustomOpacityDark") {
        settings.windowEffectCustomOpacityDark.value = entry.value;
      } else if (entry.name == "useWindowsAccent") {
        settings.useWindowsAccent.value = entry.value;
      }
    }
    settings.save();
    return settings;
  }

  Future<DisplayMode> getDisplayMode() async {
    List<DisplayMode> modes = await FlutterDisplayMode.supported;
    return modes.firstWhereOrNull((element) => element.refreshRate == refreshRate.value) ?? DisplayMode.auto;
  }

  Settings save() {
    Map<String, dynamic> map = toMap(includeAll: true);
    map.forEach((key, value) {
      if (value is bool) {
        settings.prefs.setBool(key, value);
      } else if (value is String) {
        settings.prefs.setString(key, value);
      } else if (value is int) {
        settings.prefs.setInt(key, value);
      } else if (value is double) {
        settings.prefs.setDouble(key, value);
      }
    });
    return this;
  }

  static Settings getSettings() {
    Set<String> keys = settings.prefs.getKeys();

    Map<String, dynamic> items = {};
    for (String s in keys) {
      items[s] = settings.prefs.get(s);
    }
    if (items.isNotEmpty) {
      return Settings.fromMap(items);
    } else {
      return Settings();
    }
  }

  static Future<Settings> getSettingsOld(Database db) async {
    List<Map<String, dynamic>> result = await db.query("config");
    if (result.isEmpty) return Settings();
    List<ConfigEntry> entries = [];
    for (Map<String, dynamic> setting in result) {
      entries.add(ConfigEntry.fromMap(setting));
    }
    return Settings.fromConfigEntries(entries);
  }

  Map<String, dynamic> toMap({bool includeAll = false}) {
    Map<String, dynamic> map = {
      'autoDownload': autoDownload.value,
      'onlyWifiDownload': onlyWifiDownload.value,
      'autoSave': autoSave.value,
      'autoOpenKeyboard': autoOpenKeyboard.value,
      'hideTextPreviews': hideTextPreviews.value,
      'showIncrementalSync': showIncrementalSync.value,
      'lowMemoryMode': lowMemoryMode.value,
      'lastIncrementalSync': lastIncrementalSync.value,
      'refreshRate': refreshRate.value,
      'colorfulAvatars': colorfulAvatars.value,
      'colorfulBubbles': colorfulBubbles.value,
      'hideDividers': hideDividers.value,
      'scrollVelocity': scrollVelocity.value,
      'sendWithReturn': sendWithReturn.value,
      'doubleTapForDetails': doubleTapForDetails.value,
      'denseChatTiles': denseChatTiles.value,
      'smartReply': smartReply.value,
      'reducedForehead': reducedForehead.value,
      'preCachePreviewImages': preCachePreviewImages.value,
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
      'colorblindMode': colorblindMode.value,
      'showDeliveryTimestamps': showDeliveryTimestamps.value,
      'previewCompressionQuality': previewCompressionQuality.value,
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
      'closeToTray': closeToTray.value,
      'betterScrolling': betterScrolling.value,
      'betterScrollingMultiplier': betterScrollingMultiplier.value,
      'minimizeToTray': minimizeToTray.value,
      'selectedActionIndices': selectedActionIndices,
      'actionList': actionList,
      'askWhereToSave': askWhereToSave.value,
      'indicatorsOnPinnedChats': statusIndicatorsOnChats.value,
      'apiTimeout': apiTimeout.value,
      'allowUpsideDownRotation': allowUpsideDownRotation.value,
      'swipeToReply': swipeToReply.value,
      'privateAPISend': privateAPISend.value,
      'highlightSelectedChat': highlightSelectedChat.value,
      'enablePrivateAPI': enablePrivateAPI.value,
      'privateSendTypingIndicators': privateSendTypingIndicators.value,
      'privateMarkChatAsRead': privateMarkChatAsRead.value,
      'privateManualMarkAsRead': privateManualMarkAsRead.value,
      'privateSubjectLine': privateSubjectLine.value,
      'redactedMode': redactedMode.value,
      'hideMessageContent': hideMessageContent.value,
      'hideReactions': hideReactions.value,
      'hideAttachments': hideAttachments.value,
      'hideEmojis': hideEmojis.value,
      'hideAttachmentTypes': hideAttachmentTypes.value,
      'hideContactPhotos': hideContactPhotos.value,
      'hideContactInfo': hideContactInfo.value,
      'removeLetterAvatars': removeLetterAvatars.value,
      'generateFakeContactNames': generateFakeContactNames.value,
      'generateFakeMessageContent': generateFakeMessageContent.value,
      'enableQuickTapback': enableQuickTapback.value,
      'quickTapbackType': quickTapbackType.value,
      'iosShowPin': iosShowPin.value,
      'iosShowAlert': iosShowAlert.value,
      'iosShowDelete': iosShowDelete.value,
      'iosShowMarkRead': iosShowMarkRead.value,
      'iosShowArchive': iosShowArchive.value,
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
    };
    if (includeAll) {
      map.addAll({
        'guidAuthKey': guidAuthKey.value,
        'serverAddress': serverAddress.value,
        'finishedSetup': finishedSetup.value,
        'colorsFromMedia': colorsFromMedia.value,
        'monetTheming': monetTheming.value.index,
      });
    }
    return map;
  }

  static void updateFromMap(Map<String, dynamic> map) {
    settings.settings.autoDownload.value = map['autoDownload'] ?? true;
    settings.settings.onlyWifiDownload.value = map['onlyWifiDownload'] ?? false;
    settings.settings.autoSave.value = map['autoSave'] ?? false;
    settings.settings.autoOpenKeyboard.value = map['autoOpenKeyboard'] ?? true;
    settings.settings.hideTextPreviews.value = map['hideTextPreviews'] ?? false;
    settings.settings.showIncrementalSync.value = map['showIncrementalSync'] ?? false;
    settings.settings.lowMemoryMode.value = map['lowMemoryMode'] ?? false;
    settings.settings.refreshRate.value = map['refreshRate'] ?? 0;
    settings.settings.colorfulAvatars.value = map['colorfulAvatars'] ?? false;
    settings.settings.colorfulBubbles.value = map['colorfulBubbles'] ?? false;
    settings.settings.hideDividers.value = map['hideDividers'] ?? false;
    settings.settings.scrollVelocity.value = map['scrollVelocity'] is int?
        ? (map['scrollVelocity'] as int? ?? 1).toDouble()
        : map['scrollVelocity'] as double? ?? 1.0;
    settings.settings.sendWithReturn.value = map['sendWithReturn'] ?? false;
    settings.settings.doubleTapForDetails.value = map['doubleTapForDetails'] ?? false;
    settings.settings.denseChatTiles.value = map['denseChatTiles'] ?? false;
    settings.settings.smartReply.value = map['smartReply'] ?? false;
    settings.settings.reducedForehead.value = map['reducedForehead'] ?? false;
    settings.settings.preCachePreviewImages.value = map['preCachePreviewImages'] ?? true;
    settings.settings.showConnectionIndicator.value = map['showConnectionIndicator'] ?? false;
    settings.settings.showSyncIndicator.value = map['showSyncIndicator'] ?? true;
    settings.settings.sendDelay.value = map['sendDelay'] ?? 0;
    settings.settings.recipientAsPlaceholder.value = map['recipientAsPlaceholder'] ?? false;
    settings.settings.hideKeyboardOnScroll.value = map['hideKeyboardOnScroll'] ?? false;
    settings.settings.moveChatCreatorToHeader.value = map['moveChatCreatorToHeader'] ?? false;
    settings.settings.cameraFAB.value = map['cameraFAB'] ?? false;
    settings.settings.swipeToCloseKeyboard.value = map['swipeToCloseKeyboard'] ?? false;
    settings.settings.swipeToOpenKeyboard.value = map['swipeToOpenKeyboard'] ?? false;
    settings.settings.openKeyboardOnSTB.value = map['openKeyboardOnSTB'] ?? false;
    settings.settings.swipableConversationTiles.value = map['swipableConversationTiles'] ?? false;
    settings.settings.colorblindMode.value = map['colorblindMode'] ?? false;
    settings.settings.showDeliveryTimestamps.value = map['showDeliveryTimestamps'] ?? false;
    settings.settings.previewCompressionQuality.value = map['previewCompressionQuality'] ?? 50;
    settings.settings.filteredChatList.value = map['filteredChatList'] ?? false;
    settings.settings.startVideosMuted.value = map['startVideosMuted'] ?? true;
    settings.settings.startVideosMutedFullscreen.value = map['startVideosMutedFullscreen'] ?? true;
    settings.settings.use24HrFormat.value = map['use24HrFormat'] ?? false;
    settings.settings.alwaysShowAvatars.value = map['alwaysShowAvatars'] ?? false;
    settings.settings.notifyOnChatList.value = map['notifyOnChatList'] ?? false;
    settings.settings.notifyReactions.value = map['notifyReactions'] ?? true;
    settings.settings.notificationSound.value = map['notificationSound'] ?? "default";
    settings.settings.globalTextDetection.value = map['globalTextDetection'] ?? "";
    settings.settings.filterUnknownSenders.value = map['filterUnknownSenders'] ?? false;
    settings.settings.tabletMode.value = kIsDesktop || (map['tabletMode'] ?? true);
    settings.settings.immersiveMode.value = map['immersiveMode'] ?? false;
    settings.settings.avatarScale.value = map['avatarScale']?.toDouble() ?? 1.0;
    settings.settings.launchAtStartup.value = map['launchAtStartup'] ?? false;
    settings.settings.closeToTray.value = map['closeToTray'] ?? true;
    settings.settings.betterScrolling.value = map['betterScrolling'] ?? false;
    settings.settings.betterScrollingMultiplier.value = (map['betterScrollingMultiplier'] ?? 7.0).toDouble();
    settings.settings.minimizeToTray.value = map['minimizeToTray'] ?? false;
    settings.settings.askWhereToSave.value = map['askWhereToSave'] ?? false;
    settings.settings.statusIndicatorsOnChats.value = map['indicatorsOnPinnedChats'] ?? false;
    settings.settings.apiTimeout.value = map['apiTimeout'] ?? 15000;
    settings.settings.allowUpsideDownRotation.value = map['allowUpsideDownRotation'] ?? false;
    settings.settings.swipeToReply.value = map['swipeToReply'] ?? false;
    settings.settings.privateAPISend.value = map['privateAPISend'] ?? false;
    settings.settings.enablePrivateAPI.value = map['enablePrivateAPI'] ?? false;
    settings.settings.privateSendTypingIndicators.value = map['privateSendTypingIndicators'] ?? false;
    settings.settings.privateMarkChatAsRead.value = map['privateMarkChatAsRead'] ?? false;
    settings.settings.privateManualMarkAsRead.value = map['privateManualMarkAsRead'] ?? false;
    settings.settings.privateSubjectLine.value = map['privateSubjectLine'] ?? false;
    settings.settings.redactedMode.value = map['redactedMode'] ?? false;
    settings.settings.hideMessageContent.value = map['hideMessageContent'] ?? true;
    settings.settings.hideReactions.value = map['hideReactions'] ?? false;
    settings.settings.hideAttachments.value = map['hideAttachments'] ?? true;
    settings.settings.hideEmojis.value = map['hideEmojis'] ?? false;
    settings.settings.hideAttachmentTypes.value = map['hideAttachmentTypes'] ?? false;
    settings.settings.hideContactPhotos.value = map['hideContactPhotos'] ?? true;
    settings.settings.hideContactInfo.value = map['hideContactInfo'] ?? true;
    settings.settings.removeLetterAvatars.value = map['removeLetterAvatars'] ?? true;
    settings.settings.generateFakeContactNames.value = map['generateFakeContactNames'] ?? false;
    settings.settings.generateFakeMessageContent.value = map['generateFakeMessageContent'] ?? false;
    settings.settings.enableQuickTapback.value = map['enableQuickTapback'] ?? false;
    settings.settings.quickTapbackType.value = map['quickTapbackType'] ?? ReactionTypes.toList()[0];
    settings.settings.iosShowPin.value = map['iosShowPin'] ?? true;
    settings.settings.iosShowAlert.value = map['iosShowAlert'] ?? true;
    settings.settings.iosShowDelete.value = map['iosShowDelete'] ?? true;
    settings.settings.iosShowMarkRead.value = map['iosShowMarkRead'] ?? true;
    settings.settings.iosShowArchive.value = map['iosShowArchive'] ?? true;
    settings.settings.materialRightAction.value = map['materialRightAction'] != null
        ? MaterialSwipeAction.values[map['materialRightAction']]
        : MaterialSwipeAction.pin;
    settings.settings.materialLeftAction.value = map['materialLeftAction'] != null
        ? MaterialSwipeAction.values[map['materialLeftAction']]
        : MaterialSwipeAction.archive;
    settings.settings.shouldSecure.value = map['shouldSecure'] ?? false;
    settings.settings.securityLevel.value =
        map['securityLevel'] != null ? SecurityLevel.values[map['securityLevel']] : SecurityLevel.locked;
    settings.settings.incognitoKeyboard.value = map['incognitoKeyboard'] ?? false;
    settings.settings.skin.value = map['skin'] != null ? Skins.values[map['skin']] : Skins.iOS;
    settings.settings.theme.value = map['theme'] != null ? ThemeMode.values[map['theme']] : ThemeMode.system;
    settings.settings.fullscreenViewerSwipeDir.value = map['fullscreenViewerSwipeDir'] != null
        ? SwipeDirection.values[map['fullscreenViewerSwipeDir']]
        : SwipeDirection.RIGHT;
    settings.settings.pinRowsPortrait.value = map['pinRowsPortrait'] ?? 3;
    settings.settings.pinColumnsPortrait.value = map['pinColumnsPortrait'] ?? 3;
    settings.settings.pinRowsLandscape.value = map['pinRowsLandscape'] ?? 1;
    settings.settings.pinColumnsLandscape.value = map['pinColumnsLandscape'] ?? 6;
    settings.settings.maxAvatarsInGroupWidget.value = map['maxAvatarsInGroupWidget'] ?? 4;
    settings.settings.useCustomTitleBar.value = map['useCustomTitleBar'] ?? true;
    settings.settings.selectedActionIndices.value = ((map['selectedActionIndices'] ?? [0, 1, 2, 3, 4]) as List).cast<int>();
    settings.settings.actionList.value = ((map['actionList'] ?? ["Mark Read", ReactionTypes.LOVE, ReactionTypes.LIKE, ReactionTypes.LAUGH, ReactionTypes.EMPHASIZE, ReactionTypes.DISLIKE, ReactionTypes.QUESTION]) as List).cast<String>();
    settings.settings.windowEffect.value = WindowEffect.values.firstWhereOrNull((e) => e.name == map['windowEffect']) ?? WindowEffect.disabled;
    settings.settings.windowEffectCustomOpacityLight.value = map['windowEffectCustomOpacityLight'] ?? 0.5;
    settings.settings.windowEffectCustomOpacityDark.value = map['windowEffectCustomOpacityDark'] ?? 0.5;
    settings.settings.useWindowsAccent.value = map['useWindowsAccent'] ?? false;
    settings.settings.save();
  }

  static Settings fromMap(Map<String, dynamic> map) {
    Settings s = Settings();
    s.guidAuthKey.value = map['guidAuthKey'] ?? "";
    s.serverAddress.value = map['serverAddress'] ?? "";
    s.finishedSetup.value = map['finishedSetup'] ?? false;
    s.autoDownload.value = map['autoDownload'] ?? true;
    s.autoSave.value = map['autoSave'] ?? false;
    s.onlyWifiDownload.value = map['onlyWifiDownload'] ?? false;
    s.autoOpenKeyboard.value = map['autoOpenKeyboard'] ?? true;
    s.hideTextPreviews.value = map['hideTextPreviews'] ?? false;
    s.showIncrementalSync.value = map['showIncrementalSync'] ?? false;
    s.lowMemoryMode.value = map['lowMemoryMode'] ?? false;
    s.lastIncrementalSync.value = map['lastIncrementalSync'] ?? 0;
    s.refreshRate.value = map['refreshRate'] ?? 0;
    s.colorfulAvatars.value = map['colorfulAvatars'] ?? false;
    s.colorfulBubbles.value = map['colorfulBubbles'] ?? false;
    s.hideDividers.value = map['hideDividers'] ?? false;
    s.scrollVelocity.value = map['scrollVelocity']?.toDouble() ?? 1;
    s.sendWithReturn.value = map['sendWithReturn'] ?? false;
    s.doubleTapForDetails.value = map['doubleTapForDetails'] ?? false;
    s.denseChatTiles.value = map['denseChatTiles'] ?? false;
    s.smartReply.value = map['smartReply'] ?? false;
    s.reducedForehead.value = map['reducedForehead'] ?? false;
    s.preCachePreviewImages.value = map['preCachePreviewImages'] ?? true;
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
    s.colorblindMode.value = map['colorblindMode'] ?? false;
    s.showDeliveryTimestamps.value = map['showDeliveryTimestamps'] ?? false;
    s.previewCompressionQuality.value = map['previewCompressionQuality'] ?? 50;
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
    s.closeToTray.value = map['closeToTray'] ?? true;
    s.betterScrolling.value = map['betterScrolling'] ?? false;
    s.betterScrollingMultiplier.value = (map['betterScrollingMultiplier'] ?? 7.0).toDouble();
    s.minimizeToTray.value = map['minimizeToTray'] ?? false;
    s.askWhereToSave.value = map['askWhereToSave'] ?? false;
    s.statusIndicatorsOnChats.value = map['indicatorsOnPinnedChats'] ?? false;
    s.apiTimeout.value = map['apiTimeout'] ?? 15000;
    s.allowUpsideDownRotation.value = map['allowUpsideDownRotation'] ?? false;
    s.swipeToReply.value = map['swipeToReply'] ?? false;
    s.privateAPISend.value = map['privateAPISend'] ?? false;
    s.enablePrivateAPI.value = map['enablePrivateAPI'] ?? false;
    s.privateSendTypingIndicators.value = map['privateSendTypingIndicators'] ?? false;
    s.privateMarkChatAsRead.value = map['privateMarkChatAsRead'] ?? false;
    s.privateManualMarkAsRead.value = map['privateManualMarkAsRead'] ?? false;
    s.privateSubjectLine.value = map['privateSubjectLine'] ?? false;
    s.redactedMode.value = map['redactedMode'] ?? false;
    s.hideMessageContent.value = map['hideMessageContent'] ?? true;
    s.hideReactions.value = map['hideReactions'] ?? false;
    s.hideAttachments.value = map['hideAttachments'] ?? true;
    s.hideEmojis.value = map['hideEmojis'] ?? false;
    s.hideAttachmentTypes.value = map['hideAttachmentTypes'] ?? false;
    s.hideContactPhotos.value = map['hideContactPhotos'] ?? true;
    s.hideContactInfo.value = map['hideContactInfo'] ?? true;
    s.removeLetterAvatars.value = map['removeLetterAvatars'] ?? true;
    s.generateFakeContactNames.value = map['generateFakeContactNames'] ?? false;
    s.generateFakeMessageContent.value = map['generateFakeMessageContent'] ?? false;
    s.enableQuickTapback.value = map['enableQuickTapback'] ?? false;
    s.quickTapbackType.value = map['quickTapbackType'] ?? ReactionTypes.toList()[0];
    s.iosShowPin.value = map['iosShowPin'] ?? true;
    s.iosShowAlert.value = map['iosShowAlert'] ?? true;
    s.iosShowDelete.value = map['iosShowDelete'] ?? true;
    s.iosShowMarkRead.value = map['iosShowMarkRead'] ?? true;
    s.iosShowArchive.value = map['iosShowArchive'] ?? true;
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
    s.pinColumnsLandscape.value = map['pinColumnsLandscape'] ?? 6;
    s.maxAvatarsInGroupWidget.value = map['maxAvatarsInGroupWidget'] ?? 4;
    s.useCustomTitleBar.value = map['useCustomTitleBar'] ?? true;
    s.selectedActionIndices.value = ((map['selectedActionIndices'] ?? [0, 1, 2, 3, 4]) as List).cast<int>();
    s.actionList.value = ((map['actionList'] ?? ["Mark Read", ReactionTypes.LOVE, ReactionTypes.LIKE, ReactionTypes.LAUGH, ReactionTypes.EMPHASIZE, ReactionTypes.DISLIKE, ReactionTypes.QUESTION]) as List).cast<String>();
    s.windowEffect.value = WindowEffect.values.firstWhereOrNull((e) => e.name == map['windowEffect']) ?? WindowEffect.disabled;
    s.windowEffectCustomOpacityLight.value = map['windowEffectCustomOpacityLight'] ?? 0.5;
    s.windowEffectCustomOpacityDark.value = map['windowEffectCustomOpacityDark'] ?? 0.5;
    s.useWindowsAccent.value = map['useWindowsAccent'] ?? false;
    return s;
  }
}
