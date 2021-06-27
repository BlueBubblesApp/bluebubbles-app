import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/config_entry.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:sqflite/sqflite.dart';

class Settings {
  String guidAuthKey = "";
  String serverAddress = "";
  bool finishedSetup = false;
  RxInt chunkSize = 500.obs;
  RxBool autoDownload = true.obs;
  RxBool onlyWifiDownload = false.obs;
  bool autoOpenKeyboard = true;
  bool hideTextPreviews = false;
  bool showIncrementalSync = false;
  bool lowMemoryMode = false;
  int lastIncrementalSync = 0;
  int displayMode = 0;
  bool colorfulAvatars = false;
  bool colorfulBubbles = false;
  bool hideDividers = false;
  bool sendTypingIndicators = false;
  double scrollVelocity = 1.00;
  bool sendWithReturn = false;
  bool doubleTapForDetails = false;
  bool denseChatTiles = false;
  bool smartReply = false;
  bool reducedForehead = false;
  bool preCachePreviewImages = true;
  bool showConnectionIndicator = false;
  bool showSyncIndicator = true;
  int sendDelay;
  bool recipientAsPlaceholder = false;
  bool hideKeyboardOnScroll = false;
  bool moveChatCreatorToHeader = false;
  bool swipeToCloseKeyboard = false;
  bool swipeToOpenKeyboard = false;
  bool openKeyboardOnSTB = false;
  bool swipableConversationTiles = false;
  int smartReplySampleSize = 2;
  bool colorblindMode = false;
  bool showDeliveryTimestamps = false;
  RxInt previewCompressionQuality = 25.obs;
  bool filteredChatList = false;

  // String emojiFontFamily;

  // Private API features
  bool enablePrivateAPI = false;
  bool privateSendTypingIndicators = false;
  bool privateMarkChatAsRead = false;
  bool privateManualMarkAsRead = false;

  // Redacted Mode Settings
  bool redactedMode = false;
  bool hideMessageContent = true;
  bool hideReactions = false;
  bool hideAttachments = true;
  bool hideAttachmentTypes = false;
  bool hideContactPhotos = true;
  bool hideContactInfo = true;
  bool removeLetterAvatars = true;
  bool generateFakeContactNames = false;
  bool generateFakeMessageContent = false;

  Skins skin = Skins.IOS;
  ThemeMode theme = ThemeMode.system;

  Settings();

  //todo make sure to change here!!
  factory Settings.fromConfigEntries(List<ConfigEntry> entries) {
    Settings settings = new Settings();
    for (ConfigEntry entry in entries) {
      if (entry.name == "serverAddress") {
        settings.serverAddress = entry.value;
      } else if (entry.name == "guidAuthKey") {
        settings.guidAuthKey = entry.value;
      } else if (entry.name == "finishedSetup") {
        settings.finishedSetup = entry.value;
      } else if (entry.name == "chunkSize") {
        settings.chunkSize.value = entry.value;
      } else if (entry.name == "autoOpenKeyboard") {
        settings.autoOpenKeyboard = entry.value;
      } else if (entry.name == "autoDownload") {
        settings.autoDownload.value = entry.value;
      } else if (entry.name == "onlyWifiDownload") {
        settings.onlyWifiDownload.value = entry.value;
      } else if (entry.name == "hideTextPreviews") {
        settings.hideTextPreviews = entry.value;
      } else if (entry.name == "showIncrementalSync") {
        settings.showIncrementalSync = entry.value;
      } else if (entry.name == "lowMemoryMode") {
        settings.lowMemoryMode = entry.value;
      } else if (entry.name == "lastIncrementalSync") {
        settings.lastIncrementalSync = entry.value;
      } else if (entry.name == "displayMode") {
        settings.displayMode = entry.value;
      } else if (entry.name == "rainbowBubbles") {
        settings.colorfulAvatars = entry.value;
      } else if (entry.name == "colorfulBubbles") {
        settings.colorfulBubbles = entry.value;
      } else if (entry.name == "hideDividers") {
        settings.hideDividers = entry.value;
      } else if (entry.name == "theme") {
        settings.theme = ThemeMode.values[entry.value];
      } else if (entry.name == "skin") {
        settings.skin = Skins.values[entry.value];
      } else if (entry.name == "sendTypingIndicators") {
        settings.sendTypingIndicators = entry.value;
      } else if (entry.name == "scrollVelocity") {
        settings.scrollVelocity = entry.value;
      } else if (entry.name == "sendWithReturn") {
        settings.sendWithReturn = entry.value;
      } else if (entry.name == "doubleTapForDetails") {
        settings.doubleTapForDetails = entry.value;
      } else if (entry.name == "denseChatTiles") {
        settings.denseChatTiles = entry.value;
      } else if (entry.name == "smartReply") {
        settings.smartReply = entry.value;
      } else if (entry.name == "reducedForehead") {
        settings.reducedForehead = entry.value;
      } else if (entry.name == "preCachePreviewImages") {
        settings.preCachePreviewImages = entry.value;
      } else if (entry.name == "showConnectionIndicator") {
        settings.showConnectionIndicator = entry.value;
      } else if (entry.name == "sendDelay") {
        settings.sendDelay = entry.value;
      } else if (entry.name == "recipientAsPlaceholder") {
        settings.recipientAsPlaceholder = entry.value;
      } else if (entry.name == "hideKeyboardOnScroll") {
        settings.hideKeyboardOnScroll = entry.value;
      } else if (entry.name == "swipeToOpenKeyboard") {
        settings.swipeToOpenKeyboard = entry.value;
      } else if (entry.name == "newMessageMenuBar") {
        settings.moveChatCreatorToHeader = entry.value;
      } else if (entry.name == "swipeToCloseKeyboard") {
        settings.swipeToCloseKeyboard = entry.value;
      } else if (entry.name == "moveChatCreatorToHeader") {
        settings.moveChatCreatorToHeader = entry.value;
      } else if (entry.name == "openKeyboardOnSTB") {
        settings.openKeyboardOnSTB = entry.value;
      } else if (entry.name == "swipableConversationTiles") {
        settings.swipableConversationTiles = entry.value;
      } else if (entry.name == "enablePrivateAPI") {
        settings.enablePrivateAPI = entry.value;
      } else if (entry.name == "privateSendTypingIndicators") {
        settings.privateSendTypingIndicators = entry.value;
      } else if (entry.name == "smartReplySampleSize") {
        settings.smartReplySampleSize = entry.value;
      } else if (entry.name == "colorblindMode") {
        settings.colorblindMode = entry.value;
      } else if (entry.name == "privateMarkChatAsRead") {
        settings.privateMarkChatAsRead = entry.value;
      } else if (entry.name == "privateManualMarkAsRead") {
        settings.privateManualMarkAsRead = entry.value;
      } else if (entry.name == "showSyncIndicator") {
        settings.showSyncIndicator = entry.value;
      } else if (entry.name == "showDeliveryTimestamps") {
        settings.showDeliveryTimestamps = entry.value;
      } else if (entry.name == "redactedMode") {
        settings.redactedMode = entry.value;
      } else if (entry.name == "hideMessageContent") {
        settings.hideMessageContent = entry.value;
      } else if (entry.name == "hideReactions") {
        settings.hideReactions = entry.value;
      } else if (entry.name == "hideAttachments") {
        settings.hideAttachments = entry.value;
      } else if (entry.name == "hideAttachmentTypes") {
        settings.hideAttachmentTypes = entry.value;
      } else if (entry.name == "hideContactPhotos") {
        settings.hideContactPhotos = entry.value;
      } else if (entry.name == "hideContactInfo") {
        settings.hideContactInfo = entry.value;
      } else if (entry.name == "removeLetterAvatars") {
        settings.removeLetterAvatars = entry.value;
      } else if (entry.name == "generateFakeContactNames") {
        settings.generateFakeContactNames = entry.value;
      } else if (entry.name == "generateFakeMessageContent") {
        settings.generateFakeMessageContent = entry.value;
      } else if (entry.name == "previewCompressionQuality") {
        settings.previewCompressionQuality.value = entry.value;
      } else if (entry.name == "filteredChatList") {
        settings.filteredChatList = entry.value;
      }

      // else if (entry.name == "emojiFontFamily") {
      //   settings.emojiFontFamily = entry.value;
      // }
    }
    settings.save(updateIfAbsent: false);
    return settings;
  }

  Future<DisplayMode> getDisplayMode() async {
    if (displayMode == null) return FlutterDisplayMode.current;

    List<DisplayMode> modes = await FlutterDisplayMode.supported;
    modes = modes.where((element) => element.id == displayMode).toList();

    DisplayMode mode;
    if (modes.isEmpty) {
      mode = await FlutterDisplayMode.current;
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
    Database db = await DBProvider.db.database;

    List<Map<String, dynamic>> result = await db.query("config");
    if (result.isEmpty) return new Settings();
    List<ConfigEntry> entries = [];
    for (Map<String, dynamic> setting in result) {
      entries.add(ConfigEntry.fromMap(setting));
    }
    return Settings.fromConfigEntries(entries);
  }

  //todo make sure to change here!!
  List<ConfigEntry> toEntries() => [
        ConfigEntry(
          name: "serverAddress",
          value: this.serverAddress,
          type: this.serverAddress.runtimeType,
        ),
        ConfigEntry(
          name: "guidAuthKey",
          value: this.guidAuthKey,
          type: this.guidAuthKey.runtimeType,
        ),
        ConfigEntry(
          name: "finishedSetup",
          value: this.finishedSetup,
          type: this.finishedSetup.runtimeType,
        ),
        ConfigEntry(
          name: "chunkSize",
          value: this.chunkSize.value,
          type: this.chunkSize.runtimeType,
        ),
        ConfigEntry(
          name: "autoOpenKeyboard",
          value: this.autoOpenKeyboard,
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
          value: this.hideTextPreviews,
          type: this.hideTextPreviews.runtimeType,
        ),
        ConfigEntry(
          name: "showIncrementalSync",
          value: this.showIncrementalSync,
          type: this.showIncrementalSync.runtimeType,
        ),
        ConfigEntry(
          name: "lowMemoryMode",
          value: this.lowMemoryMode,
          type: this.lowMemoryMode.runtimeType,
        ),
        ConfigEntry(
          name: "lastIncrementalSync",
          value: this.lastIncrementalSync,
          type: this.lastIncrementalSync.runtimeType,
        ),
        ConfigEntry(
          name: "displayMode",
          value: this.displayMode,
          type: this.displayMode.runtimeType,
        ),
        ConfigEntry(
          name: "rainbowBubbles",
          value: this.colorfulAvatars,
          type: this.colorfulAvatars.runtimeType,
        ),
        ConfigEntry(
          name: "colorfulBubbles",
          value: this.colorfulBubbles,
          type: this.colorfulBubbles.runtimeType,
        ),
        ConfigEntry(
          name: "hideDividers",
          value: this.hideDividers,
          type: this.hideDividers.runtimeType,
        ),
        ConfigEntry(
          name: "theme",
          value: this.theme.index,
          type: this.theme.index.runtimeType,
        ),
        ConfigEntry(
          name: "skin",
          value: this.skin.index,
          type: this.skin.index.runtimeType,
        ),
        ConfigEntry(
          name: "sendTypingIndicators",
          value: this.sendTypingIndicators,
          type: this.sendTypingIndicators.runtimeType,
        ),
        ConfigEntry(
          name: "scrollVelocity",
          value: this.scrollVelocity,
          type: this.scrollVelocity.runtimeType,
        ),
        ConfigEntry(
          name: "sendWithReturn",
          value: this.sendWithReturn,
          type: this.sendWithReturn.runtimeType,
        ),
        ConfigEntry(
          name: "doubleTapForDetails",
          value: this.doubleTapForDetails,
          type: this.doubleTapForDetails.runtimeType,
        ),
        ConfigEntry(
          name: "denseChatTiles",
          value: this.denseChatTiles,
          type: this.denseChatTiles.runtimeType,
        ),
        ConfigEntry(
          name: "smartReply",
          value: this.smartReply,
          type: this.smartReply.runtimeType,
        ),
        ConfigEntry(
          name: "hideKeyboardOnScroll",
          value: this.hideKeyboardOnScroll,
          type: this.hideKeyboardOnScroll.runtimeType,
        ),
        ConfigEntry(
          name: "reducedForehead",
          value: this.reducedForehead,
          type: this.reducedForehead.runtimeType,
        ),
        ConfigEntry(
          name: "preCachePreviewImages",
          value: this.preCachePreviewImages,
          type: this.preCachePreviewImages.runtimeType,
        ),
        ConfigEntry(
          name: "showConnectionIndicator",
          value: this.showConnectionIndicator,
          type: this.showConnectionIndicator.runtimeType,
        ),
        ConfigEntry(
          name: "sendDelay",
          value: this.sendDelay,
          type: this.sendDelay.runtimeType,
        ),
        ConfigEntry(
          name: "recipientAsPlaceholder",
          value: this.recipientAsPlaceholder,
          type: this.recipientAsPlaceholder.runtimeType,
        ),
        ConfigEntry(
          name: "moveChatCreatorToHeader",
          value: this.moveChatCreatorToHeader,
          type: this.moveChatCreatorToHeader.runtimeType,
        ),
        ConfigEntry(
          name: "swipeToCloseKeyboard",
          value: this.swipeToCloseKeyboard,
          type: this.swipeToCloseKeyboard.runtimeType,
        ),
        ConfigEntry(
          name: "swipeToOpenKeyboard",
          value: this.swipeToOpenKeyboard,
          type: this.swipeToOpenKeyboard.runtimeType,
        ),
        ConfigEntry(
          name: "openKeyboardOnSTB",
          value: this.openKeyboardOnSTB,
          type: this.openKeyboardOnSTB.runtimeType,
        ),
        ConfigEntry(
          name: "swipableConversationTiles",
          value: this.swipableConversationTiles,
          type: this.swipableConversationTiles.runtimeType,
        ),
        ConfigEntry(
          name: "enablePrivateAPI",
          value: this.enablePrivateAPI,
          type: this.enablePrivateAPI.runtimeType,
        ),
        ConfigEntry(
          name: "privateSendTypingIndicators",
          value: this.privateSendTypingIndicators,
          type: this.privateSendTypingIndicators.runtimeType,
        ),
        ConfigEntry(
          name: "smartReplySampleSize",
          value: this.smartReplySampleSize,
          type: this.smartReplySampleSize.runtimeType,
        ),
        ConfigEntry(
          name: "colorblindMode",
          value: this.colorblindMode,
          type: this.colorblindMode.runtimeType,
        ),
        ConfigEntry(
          name: "privateMarkChatAsRead",
          value: this.privateMarkChatAsRead,
          type: this.privateMarkChatAsRead.runtimeType,
        ),
        ConfigEntry(
          name: "privateManualMarkAsRead",
          value: this.privateManualMarkAsRead,
          type: this.privateManualMarkAsRead.runtimeType,
        ),
        ConfigEntry(name: "showSyncIndicator", value: this.showSyncIndicator, type: this.showSyncIndicator.runtimeType),
        ConfigEntry(
            name: "showDeliveryTimestamps",
            value: this.showDeliveryTimestamps,
            type: this.showDeliveryTimestamps.runtimeType),
        ConfigEntry(
          name: "showSyncIndicator",
          value: this.showSyncIndicator,
          type: this.showSyncIndicator.runtimeType,
        ),
        ConfigEntry(
          name: "redactedMode",
          value: this.redactedMode,
          type: this.redactedMode.runtimeType,
        ),
        ConfigEntry(
          name: "hideMessageContent",
          value: this.hideMessageContent,
          type: this.hideMessageContent.runtimeType,
        ),
        ConfigEntry(
          name: "hideAttachments",
          value: this.hideAttachments,
          type: this.hideAttachments.runtimeType,
        ),
        ConfigEntry(
          name: "hideAttachmentTypes",
          value: this.hideAttachmentTypes,
          type: this.hideAttachmentTypes.runtimeType,
        ),
        ConfigEntry(
          name: "hideContactPhotos",
          value: this.hideContactPhotos,
          type: this.hideContactPhotos.runtimeType,
        ),
        ConfigEntry(
          name: "hideContactInfo",
          value: this.hideContactInfo,
          type: this.hideContactInfo.runtimeType,
        ),
        ConfigEntry(
          name: "removeLetterAvatars",
          value: this.removeLetterAvatars,
          type: this.removeLetterAvatars.runtimeType,
        ),
        ConfigEntry(
          name: "generateFakeContactNames",
          value: this.generateFakeContactNames,
          type: this.generateFakeContactNames.runtimeType,
        ),
        ConfigEntry(
          name: "generateFakeMessageContent",
          value: this.generateFakeMessageContent,
          type: this.generateFakeMessageContent.runtimeType,
        ),
        ConfigEntry(
          name: "previewCompressionQuality",
          value: this.previewCompressionQuality.value,
          type: this.previewCompressionQuality.runtimeType,
        ),
        ConfigEntry(
          name: "filteredChatList",
          value: this.filteredChatList,
          type: this.filteredChatList.runtimeType,
        ),
        // ConfigEntry(
        //     name: "emojiFontFamily",
        //     value: this.emojiFontFamily,
        //     type: this.emojiFontFamily.runtimeType),
      ];
}
