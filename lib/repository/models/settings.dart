import 'dart:async';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/config_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';

class Settings {
  final RxString guidAuthKey = "".obs;
  final RxString serverAddress = "".obs;
  final RxBool finishedSetup = false.obs;
  final RxInt chunkSize = 500.obs;
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
  final RxString globalTextDetection = "".obs;
  final RxBool filterUnknownSenders = false.obs;
  final RxBool tabletMode = true.obs;
  final RxBool highlightSelectedChat = true.obs;
  final RxBool immersiveMode = false.obs;
  final RxDouble avatarScale = 1.0.obs;
  final RxBool askWhereToSave = false.obs;

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

  // Linux settings
  final RxBool useCustomTitleBar = RxBool(true);

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
      } else if (entry.name == "chunkSize") {
        settings.chunkSize.value = entry.value;
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
      } else if (entry.name == "globalTextDetection") {
        settings.globalTextDetection.value = entry.value;
      } else if (entry.name == "filterUnknownSenders") {
        settings.filterUnknownSenders.value = entry.value;
      } else if (entry.name == "tabletMode") {
        settings.tabletMode.value = entry.value;
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
      } else if (entry.name == "askWhereToSave") {
        settings.askWhereToSave.value = entry.value;
      } else if (entry.name == "useCustomTitleBar") {
        settings.useCustomTitleBar.value = entry.value;
      }
    }
    settings.save();
    return settings;
  }

  Future<DisplayMode> getDisplayMode() async {
    List<DisplayMode> modes = await FlutterDisplayMode.supported;
    modes = modes.where((element) => element.refreshRate == refreshRate.value).toList();

    DisplayMode mode;
    if (modes.isEmpty) {
      mode = await FlutterDisplayMode.active;
    } else {
      mode = modes.first;
    }
    return mode;
  }

  Settings save() {
    Map<String, dynamic> map = toMap(includeAll: true);
    map.forEach((key, value) {
      if (value is bool) {
        prefs.setBool(key, value);
      } else if (value is String) {
        prefs.setString(key, value);
      } else if (value is int) {
        prefs.setInt(key, value);
      } else if (value is double) {
        prefs.setDouble(key, value);
      }
    });
    return this;
  }

  static Settings getSettings() {
    Set<String> keys = prefs.getKeys();

    Map<String, dynamic> items = {};
    for (String s in keys) {
      items[s] = prefs.get(s);
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
      'chunkSize': chunkSize.value,
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
      'minimizeToTray': minimizeToTray.value,
      'askWhereToSave': askWhereToSave.value,
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
    };
    if (includeAll) {
      map.addAll({
        'guidAuthKey': guidAuthKey.value,
        'serverAddress': serverAddress.value,
        'finishedSetup': finishedSetup.value,
        'colorsFromMedia': colorsFromMedia.value,
      });
    }
    return map;
  }

  static void updateFromMap(Map<String, dynamic> map) {
    SettingsManager().settings.chunkSize.value = map['chunkSize'] ?? 500;
    SettingsManager().settings.autoDownload.value = map['autoDownload'] ?? true;
    SettingsManager().settings.onlyWifiDownload.value = map['onlyWifiDownload'] ?? false;
    SettingsManager().settings.autoSave.value = map['autoSave'] ?? false;
    SettingsManager().settings.autoOpenKeyboard.value = map['autoOpenKeyboard'] ?? true;
    SettingsManager().settings.hideTextPreviews.value = map['hideTextPreviews'] ?? false;
    SettingsManager().settings.showIncrementalSync.value = map['showIncrementalSync'] ?? false;
    SettingsManager().settings.lowMemoryMode.value = map['lowMemoryMode'] ?? false;
    SettingsManager().settings.refreshRate.value = map['refreshRate'] ?? 0;
    SettingsManager().settings.colorfulAvatars.value = map['colorfulAvatars'] ?? false;
    SettingsManager().settings.colorfulBubbles.value = map['colorfulBubbles'] ?? false;
    SettingsManager().settings.hideDividers.value = map['hideDividers'] ?? false;
    SettingsManager().settings.scrollVelocity.value = map['scrollVelocity'] is int?
        ? (map['scrollVelocity'] as int? ?? 1).toDouble()
        : map['scrollVelocity'] as double? ?? 1.0;
    SettingsManager().settings.sendWithReturn.value = map['sendWithReturn'] ?? false;
    SettingsManager().settings.doubleTapForDetails.value = map['doubleTapForDetails'] ?? false;
    SettingsManager().settings.denseChatTiles.value = map['denseChatTiles'] ?? false;
    SettingsManager().settings.smartReply.value = map['smartReply'] ?? false;
    SettingsManager().settings.reducedForehead.value = map['reducedForehead'] ?? false;
    SettingsManager().settings.preCachePreviewImages.value = map['preCachePreviewImages'] ?? true;
    SettingsManager().settings.showConnectionIndicator.value = map['showConnectionIndicator'] ?? false;
    SettingsManager().settings.showSyncIndicator.value = map['showSyncIndicator'] ?? true;
    SettingsManager().settings.sendDelay.value = map['sendDelay'] ?? 0;
    SettingsManager().settings.recipientAsPlaceholder.value = map['recipientAsPlaceholder'] ?? false;
    SettingsManager().settings.hideKeyboardOnScroll.value = map['hideKeyboardOnScroll'] ?? false;
    SettingsManager().settings.moveChatCreatorToHeader.value = map['moveChatCreatorToHeader'] ?? false;
    SettingsManager().settings.cameraFAB.value = map['cameraFAB'] ?? false;
    SettingsManager().settings.swipeToCloseKeyboard.value = map['swipeToCloseKeyboard'] ?? false;
    SettingsManager().settings.swipeToOpenKeyboard.value = map['swipeToOpenKeyboard'] ?? false;
    SettingsManager().settings.openKeyboardOnSTB.value = map['openKeyboardOnSTB'] ?? false;
    SettingsManager().settings.swipableConversationTiles.value = map['swipableConversationTiles'] ?? false;
    SettingsManager().settings.colorblindMode.value = map['colorblindMode'] ?? false;
    SettingsManager().settings.showDeliveryTimestamps.value = map['showDeliveryTimestamps'] ?? false;
    SettingsManager().settings.previewCompressionQuality.value = map['previewCompressionQuality'] ?? 50;
    SettingsManager().settings.filteredChatList.value = map['filteredChatList'] ?? false;
    SettingsManager().settings.startVideosMuted.value = map['startVideosMuted'] ?? true;
    SettingsManager().settings.startVideosMutedFullscreen.value = map['startVideosMutedFullscreen'] ?? true;
    SettingsManager().settings.use24HrFormat.value = map['use24HrFormat'] ?? false;
    SettingsManager().settings.alwaysShowAvatars.value = map['alwaysShowAvatars'] ?? false;
    SettingsManager().settings.notifyOnChatList.value = map['notifyOnChatList'] ?? false;
    SettingsManager().settings.notifyReactions.value = map['notifyReactions'] ?? true;
    SettingsManager().settings.notificationSound.value = map['notificationSound'] ?? "default";
    SettingsManager().settings.globalTextDetection.value = map['globalTextDetection'] ?? "";
    SettingsManager().settings.filterUnknownSenders.value = map['filterUnknownSenders'] ?? false;
    SettingsManager().settings.tabletMode.value = map['tabletMode'] ?? true;
    SettingsManager().settings.immersiveMode.value = map['immersiveMode'] ?? false;
    SettingsManager().settings.avatarScale.value = map['avatarScale']?.toDouble() ?? 1.0;
    SettingsManager().settings.launchAtStartup.value = map['launchAtStartup'] ?? false;
    SettingsManager().settings.closeToTray.value = map['closeToTray'] ?? true;
    SettingsManager().settings.minimizeToTray.value = map['minimizeToTray'] ?? false;
    SettingsManager().settings.askWhereToSave.value = map['askWhereToSave'] ?? false;
    SettingsManager().settings.swipeToReply.value = map['swipeToReply'] ?? false;
    SettingsManager().settings.privateAPISend.value = map['privateAPISend'] ?? false;
    SettingsManager().settings.enablePrivateAPI.value = map['enablePrivateAPI'] ?? false;
    SettingsManager().settings.privateSendTypingIndicators.value = map['privateSendTypingIndicators'] ?? false;
    SettingsManager().settings.privateMarkChatAsRead.value = map['privateMarkChatAsRead'] ?? false;
    SettingsManager().settings.privateManualMarkAsRead.value = map['privateManualMarkAsRead'] ?? false;
    SettingsManager().settings.privateSubjectLine.value = map['privateSubjectLine'] ?? false;
    SettingsManager().settings.redactedMode.value = map['redactedMode'] ?? false;
    SettingsManager().settings.hideMessageContent.value = map['hideMessageContent'] ?? true;
    SettingsManager().settings.hideReactions.value = map['hideReactions'] ?? false;
    SettingsManager().settings.hideAttachments.value = map['hideAttachments'] ?? true;
    SettingsManager().settings.hideEmojis.value = map['hideEmojis'] ?? false;
    SettingsManager().settings.hideAttachmentTypes.value = map['hideAttachmentTypes'] ?? false;
    SettingsManager().settings.hideContactPhotos.value = map['hideContactPhotos'] ?? true;
    SettingsManager().settings.hideContactInfo.value = map['hideContactInfo'] ?? true;
    SettingsManager().settings.removeLetterAvatars.value = map['removeLetterAvatars'] ?? true;
    SettingsManager().settings.generateFakeContactNames.value = map['generateFakeContactNames'] ?? false;
    SettingsManager().settings.generateFakeMessageContent.value = map['generateFakeMessageContent'] ?? false;
    SettingsManager().settings.enableQuickTapback.value = map['enableQuickTapback'] ?? false;
    SettingsManager().settings.quickTapbackType.value = map['quickTapbackType'] ?? ReactionTypes.toList()[0];
    SettingsManager().settings.iosShowPin.value = map['iosShowPin'] ?? true;
    SettingsManager().settings.iosShowAlert.value = map['iosShowAlert'] ?? true;
    SettingsManager().settings.iosShowDelete.value = map['iosShowDelete'] ?? true;
    SettingsManager().settings.iosShowMarkRead.value = map['iosShowMarkRead'] ?? true;
    SettingsManager().settings.iosShowArchive.value = map['iosShowArchive'] ?? true;
    SettingsManager().settings.materialRightAction.value = map['materialRightAction'] != null
        ? MaterialSwipeAction.values[map['materialRightAction']]
        : MaterialSwipeAction.pin;
    SettingsManager().settings.materialLeftAction.value = map['materialLeftAction'] != null
        ? MaterialSwipeAction.values[map['materialLeftAction']]
        : MaterialSwipeAction.archive;
    SettingsManager().settings.shouldSecure.value = map['shouldSecure'] ?? false;
    SettingsManager().settings.securityLevel.value =
        map['securityLevel'] != null ? SecurityLevel.values[map['securityLevel']] : SecurityLevel.locked;
    SettingsManager().settings.incognitoKeyboard.value = map['incognitoKeyboard'] ?? false;
    SettingsManager().settings.skin.value = map['skin'] != null ? Skins.values[map['skin']] : Skins.iOS;
    SettingsManager().settings.theme.value = map['theme'] != null ? ThemeMode.values[map['theme']] : ThemeMode.system;
    SettingsManager().settings.fullscreenViewerSwipeDir.value = map['fullscreenViewerSwipeDir'] != null
        ? SwipeDirection.values[map['fullscreenViewerSwipeDir']]
        : SwipeDirection.RIGHT;
    SettingsManager().settings.pinRowsPortrait.value = map['pinRowsPortrait'] ?? 3;
    SettingsManager().settings.pinColumnsPortrait.value = map['pinColumnsPortrait'] ?? 3;
    SettingsManager().settings.pinRowsLandscape.value = map['pinRowsLandscape'] ?? 1;
    SettingsManager().settings.pinColumnsLandscape.value = map['pinColumnsLandscape'] ?? 6;
    SettingsManager().settings.maxAvatarsInGroupWidget.value = map['maxAvatarsInGroupWidget'] ?? 4;
    SettingsManager().settings.useCustomTitleBar.value = map['useCustomTitleBar'] ?? true;
    SettingsManager().settings.save();
  }

  static Settings fromMap(Map<String, dynamic> map) {
    Settings s = Settings();
    s.guidAuthKey.value = map['guidAuthKey'] ?? "";
    s.serverAddress.value = map['serverAddress'] ?? "";
    s.finishedSetup.value = map['finishedSetup'] ?? false;
    s.chunkSize.value = map['chunkSize'] ?? 500;
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
    s.globalTextDetection.value = map['globalTextDetection'] ?? "";
    s.filterUnknownSenders.value = map['filterUnknownSenders'] ?? false;
    s.tabletMode.value = map['tabletMode'] ?? true;
    s.highlightSelectedChat.value = map['highlightSelectedChat'] ?? true;
    s.immersiveMode.value = map['immersiveMode'] ?? false;
    s.avatarScale.value = map['avatarScale']?.toDouble() ?? 1.0;
    s.launchAtStartup.value = map['launchAtStartup'] ?? false;
    s.closeToTray.value = map['closeToTray'] ?? true;
    s.minimizeToTray.value = map['minimizeToTray'] ?? false;
    s.askWhereToSave.value = map['askWhereToSave'] ?? false;
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
    return s;
  }
}
