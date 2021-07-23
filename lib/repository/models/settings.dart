import 'dart:async';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/config_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';

class Settings {
  RxString guidAuthKey = "".obs;
  RxString serverAddress = "".obs;
  RxBool finishedSetup = false.obs;
  RxInt chunkSize = 500.obs;
  RxBool autoDownload = true.obs;
  RxBool onlyWifiDownload = false.obs;
  RxBool autoOpenKeyboard = true.obs;
  RxBool hideTextPreviews = false.obs;
  RxBool showIncrementalSync = false.obs;
  RxBool lowMemoryMode = false.obs;
  RxInt lastIncrementalSync = 0.obs;
  RxInt refreshRate = 0.obs;
  RxBool colorfulAvatars = false.obs;
  RxBool colorfulBubbles = false.obs;
  RxBool hideDividers = false.obs;
  RxDouble scrollVelocity = 1.00.obs;
  RxBool sendWithReturn = false.obs;
  RxBool doubleTapForDetails = false.obs;
  RxBool denseChatTiles = false.obs;
  RxBool smartReply = false.obs;
  RxBool reducedForehead = false.obs;
  RxBool preCachePreviewImages = true.obs;
  RxBool showConnectionIndicator = false.obs;
  RxBool showSyncIndicator = true.obs;
  RxInt sendDelay = 0.obs;
  RxBool recipientAsPlaceholder = false.obs;
  RxBool hideKeyboardOnScroll = false.obs;
  RxBool moveChatCreatorToHeader = false.obs;
  RxBool swipeToCloseKeyboard = false.obs;
  RxBool swipeToOpenKeyboard = false.obs;
  RxBool openKeyboardOnSTB = false.obs;
  RxBool swipableConversationTiles = false.obs;
  RxBool colorblindMode = false.obs;
  RxBool showDeliveryTimestamps = false.obs;
  RxInt previewCompressionQuality = 25.obs;
  RxBool filteredChatList = false.obs;
  RxBool startVideosMuted = true.obs;
  RxBool startVideosMutedFullscreen = true.obs;
  RxBool use24HrFormat = false.obs;
  RxBool alwaysShowAvatars = false.obs;

  // RxString emojiFontFamily;

  // Private API features
  RxBool enablePrivateAPI = false.obs;
  RxBool privateSendTypingIndicators = false.obs;
  RxBool privateMarkChatAsRead = false.obs;
  RxBool privateManualMarkAsRead = false.obs;

  // Redacted Mode Settings
  RxBool redactedMode = false.obs;
  RxBool hideMessageContent = true.obs;
  RxBool hideReactions = false.obs;
  RxBool hideAttachments = true.obs;
  RxBool hideEmojis = false.obs;
  RxBool hideAttachmentTypes = false.obs;
  RxBool hideContactPhotos = true.obs;
  RxBool hideContactInfo = true.obs;
  RxBool removeLetterAvatars = true.obs;
  RxBool generateFakeContactNames = false.obs;
  RxBool generateFakeMessageContent = false.obs;

  // Quick tapback settings
  RxBool enableQuickTapback = false.obs;
  RxString quickTapbackType = ReactionTypes.toList()[0].obs; // The 'love' reaction

  // Slideable action settings
  RxBool iosShowPin = RxBool(true);
  RxBool iosShowAlert = RxBool(true);
  RxBool iosShowDelete = RxBool(true);
  RxBool iosShowMarkRead = RxBool(true);
  RxBool iosShowArchive = RxBool(true);
  Rx<MaterialSwipeAction> materialRightAction = MaterialSwipeAction.pin.obs;
  Rx<MaterialSwipeAction> materialLeftAction = MaterialSwipeAction.archive.obs;

  Rx<Skins> skin = Skins.iOS.obs;
  Rx<ThemeMode> theme = ThemeMode.system.obs;
  Rx<SwipeDirection> fullscreenViewerSwipeDir = SwipeDirection.RIGHT.obs;

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
          name: "showSyncIndicator",
          value: this.showSyncIndicator.value,
          type: this.showSyncIndicator.runtimeType
        ),
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
        // ConfigEntry(
        //     name: "emojiFontFamily",
        //     value: this.emojiFontFamily,
        //     type: this.emojiFontFamily.runtimeType),
      ];
}
