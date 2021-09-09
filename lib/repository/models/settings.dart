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

  // final RxString emojiFontFamily;

  // Private API features
  final RxBool enablePrivateAPI = false.obs;
  final RxBool privateSendTypingIndicators = false.obs;
  final RxBool privateMarkChatAsRead = false.obs;
  final RxBool privateManualMarkAsRead = false.obs;

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

  Settings();

  factory Settings.fromConfigEntries(List<ConfigEntry> entries) {
    Settings settings = new Settings();
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
      }

      // else if (entry.name == "emojiFontFamily") {
      //   settings.emojiFontFamily = entry.value;
      // }
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
    Map<String, dynamic> map = this.toMap(includeAll: true);
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
    print(keys);

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
    if (result.isEmpty) return new Settings();
    List<ConfigEntry> entries = [];
    for (Map<String, dynamic> setting in result) {
      entries.add(ConfigEntry.fromMap(setting));
    }
    return Settings.fromConfigEntries(entries);
  }

  Map<String, dynamic> toMap({bool includeAll = false}) {
    Map<String, dynamic> map = {
      'chunkSize': this.chunkSize.value,
      'autoDownload': this.autoDownload.value,
      'onlyWifiDownload': this.onlyWifiDownload.value,
      'autoOpenKeyboard': this.autoOpenKeyboard.value,
      'hideTextPreviews': this.hideTextPreviews.value,
      'showIncrementalSync': this.showIncrementalSync.value,
      'lowMemoryMode': this.lowMemoryMode.value,
      'lastIncrementalSync': this.lastIncrementalSync.value,
      'refreshRate': this.refreshRate.value,
      'colorfulAvatars': this.colorfulAvatars.value,
      'colorfulBubbles': this.colorfulBubbles.value,
      'hideDividers': this.hideDividers.value,
      'scrollVelocity': this.scrollVelocity.value,
      'sendWithReturn': this.sendWithReturn.value,
      'doubleTapForDetails': this.doubleTapForDetails.value,
      'denseChatTiles': this.denseChatTiles.value,
      'smartReply': this.smartReply.value,
      'reducedForehead': this.reducedForehead.value,
      'preCachePreviewImages': this.preCachePreviewImages.value,
      'showConnectionIndicator': this.showConnectionIndicator.value,
      'showSyncIndicator': this.showSyncIndicator.value,
      'sendDelay': this.sendDelay.value,
      'recipientAsPlaceholder': this.recipientAsPlaceholder.value,
      'hideKeyboardOnScroll': this.hideKeyboardOnScroll.value,
      'moveChatCreatorToHeader': this.moveChatCreatorToHeader.value,
      'cameraFAB': this.cameraFAB.value,
      'swipeToCloseKeyboard': this.swipeToCloseKeyboard.value,
      'swipeToOpenKeyboard': this.swipeToOpenKeyboard.value,
      'openKeyboardOnSTB': this.openKeyboardOnSTB.value,
      'swipableConversationTiles': this.swipableConversationTiles.value,
      'colorblindMode': this.colorblindMode.value,
      'showDeliveryTimestamps': this.showDeliveryTimestamps.value,
      'previewCompressionQuality': this.previewCompressionQuality.value,
      'filteredChatList': this.filteredChatList.value,
      'startVideosMuted': this.startVideosMuted.value,
      'startVideosMutedFullscreen': this.startVideosMutedFullscreen.value,
      'use24HrFormat': this.use24HrFormat.value,
      'alwaysShowAvatars': this.alwaysShowAvatars.value,
      'notifyOnChatList': this.notifyOnChatList.value,
      'notifyReactions': this.notifyReactions.value,
      'notificationSound': this.notificationSound.value,
      'globalTextDetection': this.globalTextDetection.value,
      'filterUnknownSenders': this.filterUnknownSenders.value,
      'enablePrivateAPI': this.enablePrivateAPI.value,
      'privateSendTypingIndicators': this.privateSendTypingIndicators.value,
      'privateMarkChatAsRead': this.privateMarkChatAsRead.value,
      'privateManualMarkAsRead': this.privateManualMarkAsRead.value,
      'redactedMode': this.redactedMode.value,
      'hideMessageContent': this.hideMessageContent.value,
      'hideReactions': this.hideReactions.value,
      'hideAttachments': this.hideAttachments.value,
      'hideEmojis': this.hideEmojis.value,
      'hideAttachmentTypes': this.hideAttachmentTypes.value,
      'hideContactPhotos': this.hideContactPhotos.value,
      'hideContactInfo': this.hideContactInfo.value,
      'removeLetterAvatars': this.removeLetterAvatars.value,
      'generateFakeContactNames': this.generateFakeContactNames.value,
      'generateFakeMessageContent': this.generateFakeMessageContent.value,
      'enableQuickTapback': this.enableQuickTapback.value,
      'quickTapbackType': this.quickTapbackType.value,
      'iosShowPin': this.iosShowPin.value,
      'iosShowAlert': this.iosShowAlert.value,
      'iosShowDelete': this.iosShowDelete.value,
      'iosShowMarkRead': this.iosShowMarkRead.value,
      'iosShowArchive': this.iosShowArchive.value,
      'materialRightAction': this.materialRightAction.value.index,
      'materialLeftAction': this.materialLeftAction.value.index,
      'shouldSecure': this.shouldSecure.value,
      'securityLevel': this.securityLevel.value.index,
      'incognitoKeyboard': this.incognitoKeyboard.value,
      'skin': this.skin.value.index,
      'theme': this.theme.value.index,
      'fullscreenViewerSwipeDir': this.fullscreenViewerSwipeDir.value.index,
      'pinRowsPortrait': this.pinRowsPortrait.value,
      'pinColumnsPortrait': this.pinColumnsPortrait.value,
      'pinRowsLandscape': this.pinRowsLandscape.value,
      'pinColumnsLandscape': this.pinColumnsLandscape.value,
      'maxAvatarsInGroupWidget': this.maxAvatarsInGroupWidget.value,
    };
    if (includeAll) {
      map.addAll({
        'guidAuthKey': this.guidAuthKey.value,
        'serverAddress': this.serverAddress.value,
        'finishedSetup': this.finishedSetup.value,
        'colorsFromMedia': this.colorsFromMedia.value,
      });
    }
    return map;
  }

  static void updateFromMap(Map<String, dynamic> map) {
    SettingsManager().settings.chunkSize.value = map['chunkSize'] ?? 500;
    SettingsManager().settings.autoDownload.value = map['autoDownload'] ?? true;
    SettingsManager().settings.onlyWifiDownload.value = map['onlyWifiDownload'] ?? false;
    SettingsManager().settings.autoOpenKeyboard.value = map['autoOpenKeyboard'] ?? true;
    SettingsManager().settings.hideTextPreviews.value = map['hideTextPreviews'] ?? false;
    SettingsManager().settings.showIncrementalSync.value = map['showIncrementalSync'] ?? false;
    SettingsManager().settings.lowMemoryMode.value = map['lowMemoryMode'] ?? false;
    SettingsManager().settings.lastIncrementalSync.value = map['lastIncrementalSync'] ?? 0;
    SettingsManager().settings.refreshRate.value = map['refreshRate'] ?? 0;
    SettingsManager().settings.colorfulAvatars.value = map['colorfulAvatars'] ?? false;
    SettingsManager().settings.colorfulBubbles.value = map['colorfulBubbles'] ?? false;
    SettingsManager().settings.hideDividers.value = map['hideDividers'] ?? false;
    SettingsManager().settings.scrollVelocity.value = map['scrollVelocity'] ?? 1;
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
    SettingsManager().settings.enablePrivateAPI.value = map['enablePrivateAPI'] ?? false;
    SettingsManager().settings.privateSendTypingIndicators.value = map['privateSendTypingIndicators'] ?? false;
    SettingsManager().settings.privateMarkChatAsRead.value = map['privateMarkChatAsRead'] ?? false;
    SettingsManager().settings.privateManualMarkAsRead.value = map['privateManualMarkAsRead'] ?? false;
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
    SettingsManager().settings.materialRightAction.value = map['materialRightAction'] != null ? MaterialSwipeAction.values[map['materialRightAction']] : MaterialSwipeAction.pin;
    SettingsManager().settings.materialLeftAction.value = map['materialLeftAction'] != null ? MaterialSwipeAction.values[map['materialLeftAction']] : MaterialSwipeAction.archive;
    SettingsManager().settings.shouldSecure.value = map['shouldSecure'] ?? false;
    SettingsManager().settings.securityLevel.value = map['securityLevel'] != null ? SecurityLevel.values[map['securityLevel']] : SecurityLevel.locked;
    SettingsManager().settings.incognitoKeyboard.value = map['incognitoKeyboard'] ?? false;
    SettingsManager().settings.skin.value = map['skin'] != null ? Skins.values[map['skin']] : Skins.iOS;
    SettingsManager().settings.theme.value = map['theme'] != null ? ThemeMode.values[map['theme']] : ThemeMode.system;
    SettingsManager().settings.fullscreenViewerSwipeDir.value = map['fullscreenViewerSwipeDir'] != null ? SwipeDirection.values[map['fullscreenViewerSwipeDir']] : SwipeDirection.RIGHT;
    SettingsManager().settings.pinRowsPortrait.value = map['pinRowsPortrait'] ?? 3;
    SettingsManager().settings.pinColumnsPortrait.value = map['pinColumnsPortrait'] ?? 3;
    SettingsManager().settings.pinRowsLandscape.value = map['pinRowsLandscape'] ?? 1;
    SettingsManager().settings.pinColumnsLandscape.value = map['pinColumnsLandscape'] ?? 6;
    SettingsManager().settings.maxAvatarsInGroupWidget.value = map['maxAvatarsInGroupWidget'] ?? 4;
    SettingsManager().settings.save();
  }

  static Settings fromMap(Map<String, dynamic> map) {
    Settings s = new Settings();
    s.guidAuthKey.value = map['guidAuthKey'] ?? "";
    s.serverAddress.value = map['serverAddress'] ?? "";
    s.finishedSetup.value = map['finishedSetup'] ?? false;
    s.chunkSize.value = map['chunkSize'] ?? 500;
    s.autoDownload.value = map['autoDownload'] ?? true;
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
    s.scrollVelocity.value = map['scrollVelocity'] ?? 1;
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
    s.enablePrivateAPI.value = map['enablePrivateAPI'] ?? false;
    s.privateSendTypingIndicators.value = map['privateSendTypingIndicators'] ?? false;
    s.privateMarkChatAsRead.value = map['privateMarkChatAsRead'] ?? false;
    s.privateManualMarkAsRead.value = map['privateManualMarkAsRead'] ?? false;
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
    s.materialRightAction.value = map['materialRightAction'] != null ? MaterialSwipeAction.values[map['materialRightAction']] : MaterialSwipeAction.pin;
    s.materialLeftAction.value = map['materialLeftAction'] != null ? MaterialSwipeAction.values[map['materialLeftAction']] : MaterialSwipeAction.archive;
    s.shouldSecure.value = map['shouldSecure'] ?? false;
    s.securityLevel.value = map['securityLevel'] != null ? SecurityLevel.values[map['securityLevel']] : SecurityLevel.locked;
    s.incognitoKeyboard.value = map['incognitoKeyboard'] ?? false;
    s.skin.value = map['skin'] != null ? Skins.values[map['skin']] : Skins.iOS;
    s.theme.value = map['theme'] != null ? ThemeMode.values[map['theme']] : ThemeMode.system;
    s.fullscreenViewerSwipeDir.value = map['fullscreenViewerSwipeDir'] != null ? SwipeDirection.values[map['fullscreenViewerSwipeDir']] : SwipeDirection.RIGHT;
    s.pinRowsPortrait.value = map['pinRowsPortrait'] ?? 3;
    s.pinColumnsPortrait.value = map['pinColumnsPortrait'] ?? 3;
    s.pinRowsLandscape.value = map['pinRowsLandscape'] ?? 1;
    s.pinColumnsLandscape.value = map['pinColumnsLandscape'] ?? 6;
    s.maxAvatarsInGroupWidget.value = map['maxAvatarsInGroupWidget'] ?? 4;
    return s;
  }
}
