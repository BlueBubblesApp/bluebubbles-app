import 'package:bluebubbles/helpers/contstants.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/config_entry.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:sqflite/sqflite.dart';

class Settings {
  String guidAuthKey = "";
  String serverAddress = "";
  bool finishedSetup = false;
  int chunkSize = 500;
  bool autoDownload = true;
  bool onlyWifiDownload = false;
  bool autoOpenKeyboard = true;
  bool hideTextPreviews = false;
  bool showIncrementalSync = false;
  bool lowMemoryMode = false;
  int lastIncrementalSync = 0;
  int displayMode = 0;
  bool colorfulAvatars = false;
  bool colorfulBubbles = false;
  bool hideDividers = false;
  bool sendTypingIndicators = true;
  double scrollVelocity = 1.00;
  bool sendWithReturn = false;
  bool doubleTapForDetails = false;
  bool denseChatTiles = false;
  bool smartReply = false;
  bool reducedForehead = false;
  bool preCachePreviewImages = true;
  bool showConnectionIndicator = false;
  int sendDelay;
  bool recipientAsPlaceholder = false;
  bool hideKeyboardOnScroll = false;
  bool openKeyboardOnSTB = false;
  bool moveNewMessageToheader = false;
  bool swipeToCloseKeyboard = true;
  bool coolPinnedChatsMaterial = false;
  bool swipeToDismiss = false;
  // String emojiFontFamily;

  Skins skin = Skins.IOS;

  Settings();

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
        settings.chunkSize = entry.value;
      } else if (entry.name == "autoOpenKeyboard") {
        settings.autoOpenKeyboard = entry.value;
      } else if (entry.name == "autoDownload") {
        settings.autoDownload = entry.value;
      } else if (entry.name == "onlyWifiDownload") {
        settings.onlyWifiDownload = entry.value;
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
      } else if (entry.name == "openKeyboardOnSTB") {
        settings.openKeyboardOnSTB = entry.value;
      } else if (entry.name == "newMessageMenuBar") {
        settings.moveNewMessageToheader = entry.value;
      } else if (entry.name == "swipeToCloseKeyboard") {
        settings.swipeToCloseKeyboard = entry.value;
      } else if (entry.name == "coolPinnedChatsMaterial") {
        settings.coolPinnedChatsMaterial = entry.value;
      } else if (entry.name == "swipeToDismiss") {
        settings.swipeToDismiss = entry.value;
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

  List<ConfigEntry> toEntries() => [
        ConfigEntry(
            name: "serverAddress",
            value: this.serverAddress,
            type: this.serverAddress.runtimeType),
        ConfigEntry(
            name: "guidAuthKey",
            value: this.guidAuthKey,
            type: this.guidAuthKey.runtimeType),
        ConfigEntry(
            name: "finishedSetup",
            value: this.finishedSetup,
            type: this.finishedSetup.runtimeType),
        ConfigEntry(
            name: "chunkSize",
            value: this.chunkSize,
            type: this.chunkSize.runtimeType),
        ConfigEntry(
            name: "autoOpenKeyboard",
            value: this.autoOpenKeyboard,
            type: this.autoOpenKeyboard.runtimeType),
        ConfigEntry(
            name: "autoDownload",
            value: this.autoDownload,
            type: this.autoDownload.runtimeType),
        ConfigEntry(
            name: "onlyWifiDownload",
            value: this.onlyWifiDownload,
            type: this.onlyWifiDownload.runtimeType),
        ConfigEntry(
            name: "hideTextPreviews",
            value: this.hideTextPreviews,
            type: this.hideTextPreviews.runtimeType),
        ConfigEntry(
            name: "showIncrementalSync",
            value: this.showIncrementalSync,
            type: this.showIncrementalSync.runtimeType),
        ConfigEntry(
            name: "lowMemoryMode",
            value: this.lowMemoryMode,
            type: this.lowMemoryMode.runtimeType),
        ConfigEntry(
            name: "lastIncrementalSync",
            value: this.lastIncrementalSync,
            type: this.lastIncrementalSync.runtimeType),
        ConfigEntry(
            name: "displayMode",
            value: this.displayMode,
            type: this.displayMode.runtimeType),
        ConfigEntry(
            name: "rainbowBubbles",
            value: this.colorfulAvatars,
            type: this.colorfulAvatars.runtimeType),
        ConfigEntry(
            name: "colorfulBubbles",
            value: this.colorfulBubbles,
            type: this.colorfulBubbles.runtimeType),
        ConfigEntry(
            name: "hideDividers",
            value: this.hideDividers,
            type: this.hideDividers.runtimeType),
        ConfigEntry(
            name: "skin",
            value: this.skin.index,
            type: this.skin.index.runtimeType),
        ConfigEntry(
            name: "sendTypingIndicators",
            value: this.sendTypingIndicators,
            type: this.sendTypingIndicators.runtimeType),
        ConfigEntry(
            name: "scrollVelocity",
            value: this.scrollVelocity,
            type: this.scrollVelocity.runtimeType),
        ConfigEntry(
            name: "sendWithReturn",
            value: this.sendWithReturn,
            type: this.sendWithReturn.runtimeType),
        ConfigEntry(
            name: "doubleTapForDetails",
            value: this.doubleTapForDetails,
            type: this.doubleTapForDetails.runtimeType),
        ConfigEntry(
            name: "denseChatTiles",
            value: this.denseChatTiles,
            type: this.denseChatTiles.runtimeType),
        ConfigEntry(
            name: "smartReply",
            value: this.smartReply,
            type: this.smartReply.runtimeType),
        ConfigEntry(
            name: "hideKeyboardOnScroll",
            value: this.hideKeyboardOnScroll,
            type: this.hideKeyboardOnScroll.runtimeType),
        ConfigEntry(
            name: "reducedForehead",
            value: this.reducedForehead,
            type: this.reducedForehead.runtimeType),
        ConfigEntry(
            name: "preCachePreviewImages",
            value: this.preCachePreviewImages,
            type: this.preCachePreviewImages.runtimeType),
        ConfigEntry(
            name: "showConnectionIndicator",
            value: this.showConnectionIndicator,
            type: this.showConnectionIndicator.runtimeType),
        ConfigEntry(
            name: "sendDelay",
            value: this.sendDelay,
            type: this.sendDelay.runtimeType),
        ConfigEntry(
            name: "recipientAsPlaceholder",
            value: this.recipientAsPlaceholder,
            type: this.recipientAsPlaceholder.runtimeType),
        ConfigEntry(
            name: "openKeyboardOnSTB",
            value: this.openKeyboardOnSTB,
            type: this.openKeyboardOnSTB.runtimeType),
        ConfigEntry(
            name: "newMessageMenuBar",
            value: this.moveNewMessageToheader,
            type: this.moveNewMessageToheader.runtimeType),
        ConfigEntry(
            name: "swipeToCloseKeyboard",
            value: this.swipeToCloseKeyboard,
            type: this.swipeToCloseKeyboard.runtimeType),
        ConfigEntry(
            name: "coolPinnedChatsMaterial",
            value: this.coolPinnedChatsMaterial,
            type: this.coolPinnedChatsMaterial.runtimeType),
        ConfigEntry(
            name: "swipeToDismiss",
            value: this.swipeToDismiss,
            type: this.swipeToDismiss.runtimeType),
        // ConfigEntry(
        //     name: "emojiFontFamily",
        //     value: this.emojiFontFamily,
        //     type: this.emojiFontFamily.runtimeType),
      ];
}
