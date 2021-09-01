import 'dart:async';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/database.dart';
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
  final RxBool adjustPrimary = true.obs;
  final RxBool adjustBackground = false.obs;
  final RxString globalTextDetection = "".obs;

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
      } else if (entry.name == "adjustPrimary") {
        settings.adjustPrimary.value = entry.value;
      } else if (entry.name == "adjustBackground") {
        settings.adjustBackground.value = entry.value;
      } else if (entry.name == "globalTextDetection") {
        settings.globalTextDetection.value = entry.value;
      }

      // else if (entry.name == "emojiFontFamily") {
      //   settings.emojiFontFamily = entry.value;
      // }
    }
    settings.save(updateIfAbsent: false);
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

  Future<Settings> save({bool updateIfAbsent = true}) async {
    List<ConfigEntry> entries = this.toEntries();
    for (ConfigEntry entry in entries) {
      await entry.save("config", updateIfAbsent: updateIfAbsent);
    }
    return this;
  }

  static Future<Settings> getSettings() async {
    Database? db = await DBProvider.db.database;

    List<Map<String, dynamic>> result = await db.query("config");
    if (result.isEmpty) return new Settings();
    List<ConfigEntry> entries = [];
    for (Map<String, dynamic> setting in result) {
      entries.add(ConfigEntry.fromMap(setting));
    }
    return Settings.fromConfigEntries(entries);
  }

  List<ConfigEntry> toEntries() => [
        ConfigEntry(
          name: "serverAddress",
          value: this.serverAddress.value,
          type: this.serverAddress.runtimeType,
        ),
        ConfigEntry(
          name: "guidAuthKey",
          value: this.guidAuthKey.value,
          type: this.guidAuthKey.runtimeType,
        ),
        ConfigEntry(
          name: "finishedSetup",
          value: this.finishedSetup.value,
          type: this.finishedSetup.runtimeType,
        ),
        ConfigEntry(
          name: "chunkSize",
          value: this.chunkSize.value,
          type: this.chunkSize.runtimeType,
        ),
        ConfigEntry(
          name: "autoOpenKeyboard",
          value: this.autoOpenKeyboard.value,
          type: this.autoOpenKeyboard.runtimeType,
        ),
        ConfigEntry(
          name: "autoDownload",
          value: this.autoDownload.value,
          type: this.autoDownload.runtimeType,
        ),
        ConfigEntry(
          name: "onlyWifiDownload",
          value: this.onlyWifiDownload.value,
          type: this.onlyWifiDownload.runtimeType,
        ),
        ConfigEntry(
          name: "hideTextPreviews",
          value: this.hideTextPreviews.value,
          type: this.hideTextPreviews.runtimeType,
        ),
        ConfigEntry(
          name: "showIncrementalSync",
          value: this.showIncrementalSync.value,
          type: this.showIncrementalSync.runtimeType,
        ),
        ConfigEntry(
          name: "lowMemoryMode",
          value: this.lowMemoryMode.value,
          type: this.lowMemoryMode.runtimeType,
        ),
        ConfigEntry(
          name: "lastIncrementalSync",
          value: this.lastIncrementalSync.value,
          type: this.lastIncrementalSync.runtimeType,
        ),
        ConfigEntry(
          name: "displayMode",
          value: this.refreshRate.value,
          type: this.refreshRate.runtimeType,
        ),
        ConfigEntry(
          name: "rainbowBubbles",
          value: this.colorfulAvatars.value,
          type: this.colorfulAvatars.runtimeType,
        ),
        ConfigEntry(
          name: "colorfulBubbles",
          value: this.colorfulBubbles.value,
          type: this.colorfulBubbles.runtimeType,
        ),
        ConfigEntry(
          name: "hideDividers",
          value: this.hideDividers.value,
          type: this.hideDividers.runtimeType,
        ),
        ConfigEntry(
          name: "theme",
          value: this.theme.value.index,
          type: this.theme.value.index.runtimeType,
        ),
        ConfigEntry(
          name: "skin",
          value: this.skin.value.index,
          type: this.skin.value.index.runtimeType,
        ),
        ConfigEntry(
          name: "fullscreenViewerSwipeDir",
          value: this.fullscreenViewerSwipeDir.value.index,
          type: this.fullscreenViewerSwipeDir.value.index.runtimeType,
        ),
        ConfigEntry(
          name: "scrollVelocity",
          value: this.scrollVelocity.value,
          type: this.scrollVelocity.runtimeType,
        ),
        ConfigEntry(
          name: "sendWithReturn",
          value: this.sendWithReturn.value,
          type: this.sendWithReturn.runtimeType,
        ),
        ConfigEntry(
          name: "doubleTapForDetails",
          value: this.doubleTapForDetails.value,
          type: this.doubleTapForDetails.runtimeType,
        ),
        ConfigEntry(
          name: "denseChatTiles",
          value: this.denseChatTiles.value,
          type: this.denseChatTiles.runtimeType,
        ),
        ConfigEntry(
          name: "smartReply",
          value: this.smartReply.value,
          type: this.smartReply.runtimeType,
        ),
        ConfigEntry(
          name: "hideKeyboardOnScroll",
          value: this.hideKeyboardOnScroll.value,
          type: this.hideKeyboardOnScroll.runtimeType,
        ),
        ConfigEntry(
          name: "reducedForehead",
          value: this.reducedForehead.value,
          type: this.reducedForehead.runtimeType,
        ),
        ConfigEntry(
          name: "preCachePreviewImages",
          value: this.preCachePreviewImages.value,
          type: this.preCachePreviewImages.runtimeType,
        ),
        ConfigEntry(
          name: "showConnectionIndicator",
          value: this.showConnectionIndicator.value,
          type: this.showConnectionIndicator.runtimeType,
        ),
        ConfigEntry(
          name: "sendDelay",
          value: this.sendDelay.value,
          type: this.sendDelay.runtimeType,
        ),
        ConfigEntry(
          name: "recipientAsPlaceholder",
          value: this.recipientAsPlaceholder.value,
          type: this.recipientAsPlaceholder.runtimeType,
        ),
        ConfigEntry(
          name: "moveChatCreatorToHeader",
          value: this.moveChatCreatorToHeader.value,
          type: this.moveChatCreatorToHeader.runtimeType,
        ),
        ConfigEntry(
          name: "swipeToCloseKeyboard",
          value: this.swipeToCloseKeyboard.value,
          type: this.swipeToCloseKeyboard.runtimeType,
        ),
        ConfigEntry(
          name: "swipeToOpenKeyboard",
          value: this.swipeToOpenKeyboard.value,
          type: this.swipeToOpenKeyboard.runtimeType,
        ),
        ConfigEntry(
          name: "openKeyboardOnSTB",
          value: this.openKeyboardOnSTB.value,
          type: this.openKeyboardOnSTB.runtimeType,
        ),
        ConfigEntry(
          name: "swipableConversationTiles",
          value: this.swipableConversationTiles.value,
          type: this.swipableConversationTiles.runtimeType,
        ),
        ConfigEntry(
          name: "enablePrivateAPI",
          value: this.enablePrivateAPI.value,
          type: this.enablePrivateAPI.runtimeType,
        ),
        ConfigEntry(
          name: "privateSendTypingIndicators",
          value: this.privateSendTypingIndicators.value,
          type: this.privateSendTypingIndicators.runtimeType,
        ),
        ConfigEntry(
          name: "colorblindMode",
          value: this.colorblindMode.value,
          type: this.colorblindMode.runtimeType,
        ),
        ConfigEntry(
          name: "privateMarkChatAsRead",
          value: this.privateMarkChatAsRead.value,
          type: this.privateMarkChatAsRead.runtimeType,
        ),
        ConfigEntry(
          name: "privateManualMarkAsRead",
          value: this.privateManualMarkAsRead.value,
          type: this.privateManualMarkAsRead.runtimeType,
        ),
        ConfigEntry(
            name: "showSyncIndicator", value: this.showSyncIndicator.value, type: this.showSyncIndicator.runtimeType),
        ConfigEntry(
            name: "showDeliveryTimestamps",
            value: this.showDeliveryTimestamps.value,
            type: this.showDeliveryTimestamps.runtimeType),
        ConfigEntry(
          name: "showSyncIndicator",
          value: this.showSyncIndicator.value,
          type: this.showSyncIndicator.runtimeType,
        ),
        ConfigEntry(
          name: "redactedMode",
          value: this.redactedMode.value,
          type: this.redactedMode.runtimeType,
        ),
        ConfigEntry(
          name: "hideMessageContent",
          value: this.hideMessageContent.value,
          type: this.hideMessageContent.runtimeType,
        ),
        ConfigEntry(
          name: "hideReactions",
          value: this.hideReactions.value,
          type: this.hideReactions.runtimeType,
        ),
        ConfigEntry(
          name: "hideAttachments",
          value: this.hideAttachments.value,
          type: this.hideAttachments.runtimeType,
        ),
        ConfigEntry(
          name: "hideAttachmentTypes",
          value: this.hideAttachmentTypes.value,
          type: this.hideAttachmentTypes.runtimeType,
        ),
        ConfigEntry(
          name: "hideContactPhotos",
          value: this.hideContactPhotos.value,
          type: this.hideContactPhotos.runtimeType,
        ),
        ConfigEntry(
          name: "hideContactInfo",
          value: this.hideContactInfo.value,
          type: this.hideContactInfo.runtimeType,
        ),
        ConfigEntry(
          name: "removeLetterAvatars",
          value: this.removeLetterAvatars.value,
          type: this.removeLetterAvatars.runtimeType,
        ),
        ConfigEntry(
          name: "generateFakeContactNames",
          value: this.generateFakeContactNames.value,
          type: this.generateFakeContactNames.runtimeType,
        ),
        ConfigEntry(
          name: "generateFakeMessageContent",
          value: this.generateFakeMessageContent.value,
          type: this.generateFakeMessageContent.runtimeType,
        ),
        ConfigEntry(
          name: "previewCompressionQuality",
          value: this.previewCompressionQuality.value,
          type: this.previewCompressionQuality.runtimeType,
        ),
        ConfigEntry(
          name: "filteredChatList",
          value: this.filteredChatList.value,
          type: this.filteredChatList.runtimeType,
        ),
        ConfigEntry(
          name: "startVideosMuted",
          value: this.startVideosMuted.value,
          type: this.startVideosMuted.runtimeType,
        ),
        ConfigEntry(
          name: "startVideosMutedFullscreen",
          value: this.startVideosMutedFullscreen.value,
          type: this.startVideosMutedFullscreen.runtimeType,
        ),
        ConfigEntry(
          name: "use24HrFormat",
          value: this.use24HrFormat.value,
          type: this.use24HrFormat.runtimeType,
        ),
        ConfigEntry(
          name: "enableQuickTapback",
          value: this.enableQuickTapback.value,
          type: this.enableQuickTapback.runtimeType,
        ),
        ConfigEntry(
          name: "quickTapbackType",
          value: this.quickTapbackType.value,
          type: this.quickTapbackType.runtimeType,
        ),
        ConfigEntry(
          name: "alwaysShowAvatars",
          value: this.alwaysShowAvatars.value,
          type: this.alwaysShowAvatars.runtimeType,
        ),
        ConfigEntry(
          name: "iosShowPin",
          value: this.iosShowPin.value,
          type: this.iosShowPin.runtimeType,
        ),
        ConfigEntry(
          name: "iosShowAlert",
          value: this.iosShowAlert.value,
          type: this.iosShowAlert.runtimeType,
        ),
        ConfigEntry(
          name: "iosShowDelete",
          value: this.iosShowDelete.value,
          type: this.iosShowDelete.runtimeType,
        ),
        ConfigEntry(
          name: "iosShowMarkRead",
          value: this.iosShowMarkRead.value,
          type: this.iosShowMarkRead.runtimeType,
        ),
        ConfigEntry(
          name: "iosShowArchive",
          value: this.iosShowArchive.value,
          type: this.iosShowArchive.runtimeType,
        ),
        ConfigEntry(
          name: "materialRightAction",
          value: this.materialRightAction.value.index,
          type: this.materialRightAction.value.index.runtimeType,
        ),
        ConfigEntry(
          name: "materialLeftAction",
          value: this.materialLeftAction.value.index,
          type: this.materialLeftAction.value.index.runtimeType,
        ),
        ConfigEntry(
          name: "shouldSecure",
          value: this.shouldSecure.value,
          type: this.shouldSecure.runtimeType,
        ),
        ConfigEntry(
          name: "securityLevel",
          value: this.securityLevel.value.index,
          type: this.securityLevel.value.index.runtimeType,
        ),
        ConfigEntry(
          name: "pinRowsPortrait",
          value: this.pinRowsPortrait.value,
          type: this.pinRowsPortrait.value.runtimeType,
        ),
        ConfigEntry(
          name: "maxAvatarsInGroupWidget",
          value: this.maxAvatarsInGroupWidget.value,
          type: this.maxAvatarsInGroupWidget.value.runtimeType,
        ),
        ConfigEntry(
          name: "notifyOnChatList",
          value: this.notifyOnChatList.value,
          type: this.notifyOnChatList.runtimeType,
        ),
        ConfigEntry(
          name: "notifyReactions",
          value: this.notifyReactions.value,
          type: this.notifyReactions.runtimeType,
        ),
        ConfigEntry(
          name: "notificationSound",
          value: this.notificationSound.value,
          type: this.notificationSound.runtimeType,
        ),
        ConfigEntry(
          name: "colorsFromMedia",
          value: this.colorsFromMedia.value,
          type: this.colorsFromMedia.runtimeType,
        ),
        ConfigEntry(
          name: "adjustPrimary",
          value: this.adjustPrimary.value,
          type: this.adjustPrimary.runtimeType,
        ),
        ConfigEntry(
          name: "adjustBackground",
          value: this.adjustBackground.value,
          type: this.adjustBackground.runtimeType,
        ),
        ConfigEntry(
          name: "globalTextDetection",
          value: this.globalTextDetection.value,
          type: this.globalTextDetection.runtimeType,
        )
        // ConfigEntry(
        //     name: "emojiFontFamily",
        //     value: this.emojiFontFamily,
        //     type: this.emojiFontFamily.runtimeType),
      ];

  Map<String, dynamic> toMap() {
    return {
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
      'skin': this.skin.value.index,
      'theme': this.theme.value.index,
      'fullscreenViewerSwipeDir': this.fullscreenViewerSwipeDir.value.index,
      'pinRowsPortrait': this.pinRowsPortrait.value,
      'pinColumnsPortrait': this.pinColumnsPortrait.value,
      'pinRowsLandscape': this.pinRowsLandscape.value,
      'pinColumnsLandscape': this.pinColumnsLandscape.value,
      'maxAvatarsInGroupWidget': this.maxAvatarsInGroupWidget.value,
    };
  }

  static void updateFromMap(Map<String, dynamic> map) {
    SettingsManager().settings.chunkSize.value = map['chunkSize'];
    SettingsManager().settings.autoDownload.value = map['autoDownload'];
    SettingsManager().settings.onlyWifiDownload.value = map['onlyWifiDownload'];
    SettingsManager().settings.autoOpenKeyboard.value = map['autoOpenKeyboard'];
    SettingsManager().settings.hideTextPreviews.value = map['hideTextPreviews'];
    SettingsManager().settings.showIncrementalSync.value = map['showIncrementalSync'];
    SettingsManager().settings.lowMemoryMode.value = map['lowMemoryMode'];
    SettingsManager().settings.lastIncrementalSync.value = map['lastIncrementalSync'];
    SettingsManager().settings.refreshRate.value = map['refreshRate'];
    SettingsManager().settings.colorfulAvatars.value = map['colorfulAvatars'];
    SettingsManager().settings.colorfulBubbles.value = map['colorfulBubbles'];
    SettingsManager().settings.hideDividers.value = map['hideDividers'];
    SettingsManager().settings.scrollVelocity.value = map['scrollVelocity'];
    SettingsManager().settings.sendWithReturn.value = map['sendWithReturn'];
    SettingsManager().settings.doubleTapForDetails.value = map['doubleTapForDetails'];
    SettingsManager().settings.denseChatTiles.value = map['denseChatTiles'];
    SettingsManager().settings.smartReply.value = map['smartReply'];
    SettingsManager().settings.reducedForehead.value = map['reducedForehead'];
    SettingsManager().settings.preCachePreviewImages.value = map['preCachePreviewImages'];
    SettingsManager().settings.showConnectionIndicator.value = map['showConnectionIndicator'];
    SettingsManager().settings.showSyncIndicator.value = map['showSyncIndicator'];
    SettingsManager().settings.sendDelay.value = map['sendDelay'];
    SettingsManager().settings.recipientAsPlaceholder.value = map['recipientAsPlaceholder'];
    SettingsManager().settings.hideKeyboardOnScroll.value = map['hideKeyboardOnScroll'];
    SettingsManager().settings.moveChatCreatorToHeader.value = map['moveChatCreatorToHeader'];
    SettingsManager().settings.swipeToCloseKeyboard.value = map['swipeToCloseKeyboard'];
    SettingsManager().settings.swipeToOpenKeyboard.value = map['swipeToOpenKeyboard'];
    SettingsManager().settings.openKeyboardOnSTB.value = map['openKeyboardOnSTB'];
    SettingsManager().settings.swipableConversationTiles.value = map['swipableConversationTiles'];
    SettingsManager().settings.colorblindMode.value = map['colorblindMode'];
    SettingsManager().settings.showDeliveryTimestamps.value = map['showDeliveryTimestamps'];
    SettingsManager().settings.previewCompressionQuality.value = map['previewCompressionQuality'];
    SettingsManager().settings.filteredChatList.value = map['filteredChatList'];
    SettingsManager().settings.startVideosMuted.value = map['startVideosMuted'];
    SettingsManager().settings.startVideosMutedFullscreen.value = map['startVideosMutedFullscreen'];
    SettingsManager().settings.use24HrFormat.value = map['use24HrFormat'];
    SettingsManager().settings.alwaysShowAvatars.value = map['alwaysShowAvatars'];
    SettingsManager().settings.notifyOnChatList.value = map['notifyOnChatList'];
    SettingsManager().settings.notifyReactions.value = map['notifyReactions'];
    SettingsManager().settings.notifyReactions.value = map['notificationSound'];
    SettingsManager().settings.globalTextDetection.value = map['globalTextDetection'];
    SettingsManager().settings.enablePrivateAPI.value = map['enablePrivateAPI'];
    SettingsManager().settings.privateSendTypingIndicators.value = map['privateSendTypingIndicators'];
    SettingsManager().settings.privateMarkChatAsRead.value = map['privateMarkChatAsRead'];
    SettingsManager().settings.privateManualMarkAsRead.value = map['privateManualMarkAsRead'];
    SettingsManager().settings.redactedMode.value = map['redactedMode'];
    SettingsManager().settings.hideMessageContent.value = map['hideMessageContent'];
    SettingsManager().settings.hideReactions.value = map['hideReactions'];
    SettingsManager().settings.hideAttachments.value = map['hideAttachments'];
    SettingsManager().settings.hideEmojis.value = map['hideEmojis'];
    SettingsManager().settings.hideAttachmentTypes.value = map['hideAttachmentTypes'];
    SettingsManager().settings.hideContactPhotos.value = map['hideContactPhotos'];
    SettingsManager().settings.hideContactInfo.value = map['hideContactInfo'];
    SettingsManager().settings.removeLetterAvatars.value = map['removeLetterAvatars'];
    SettingsManager().settings.generateFakeContactNames.value = map['generateFakeContactNames'];
    SettingsManager().settings.generateFakeMessageContent.value = map['generateFakeMessageContent'];
    SettingsManager().settings.enableQuickTapback.value = map['enableQuickTapback'];
    SettingsManager().settings.quickTapbackType.value = map['quickTapbackType'];
    SettingsManager().settings.iosShowPin.value = map['iosShowPin'];
    SettingsManager().settings.iosShowAlert.value = map['iosShowAlert'];
    SettingsManager().settings.iosShowDelete.value = map['iosShowDelete'];
    SettingsManager().settings.iosShowMarkRead.value = map['iosShowMarkRead'];
    SettingsManager().settings.iosShowArchive.value = map['iosShowArchive'];
    SettingsManager().settings.materialRightAction.value = MaterialSwipeAction.values[map['materialRightAction']];
    SettingsManager().settings.materialLeftAction.value = MaterialSwipeAction.values[map['materialLeftAction']];
    SettingsManager().settings.shouldSecure.value = map['shouldSecure'];
    SettingsManager().settings.securityLevel.value = SecurityLevel.values[map['securityLevel']];
    SettingsManager().settings.skin.value = Skins.values[map['skin']];
    SettingsManager().settings.theme.value = ThemeMode.values[map['theme']];
    SettingsManager().settings.fullscreenViewerSwipeDir.value = SwipeDirection.values[map['fullscreenViewerSwipeDir']];
    SettingsManager().settings.pinRowsPortrait.value = map['pinRowsPortrait'];
    SettingsManager().settings.pinColumnsPortrait.value = map['pinColumnsPortrait'];
    SettingsManager().settings.pinRowsLandscape.value = map['pinRowsLandscape'];
    SettingsManager().settings.pinColumnsLandscape.value = map['pinColumnsLandscape'];
    SettingsManager().settings.maxAvatarsInGroupWidget.value = map['maxAvatarsInGroupWidget'];
    SettingsManager().settings.save();
  }
}
