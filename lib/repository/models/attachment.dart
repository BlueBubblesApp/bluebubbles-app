import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:sqflite/sqflite.dart';
import 'package:image_size_getter/image_size_getter.dart' as IMG;

import '../database.dart';

Attachment attachmentFromJson(String str) {
  final jsonData = json.decode(str);
  return Attachment.fromMap(jsonData);
}

String attachmentToJson(Attachment data) {
  final dyn = data.toMap();
  return json.encode(dyn);
}

class Attachment {
  int id;
  int originalROWID;
  String guid;
  String uti;
  String mimeType;
  String transferState;
  bool isOutgoing;
  String transferName;
  int totalBytes;
  bool isSticker;
  bool hideAttachment;
  String blurhash;
  int height;
  int width;

  Attachment({
    this.id,
    this.originalROWID,
    this.guid,
    this.uti,
    this.mimeType,
    this.transferState,
    this.isOutgoing,
    this.transferName,
    this.totalBytes,
    this.isSticker,
    this.hideAttachment,
    this.blurhash,
    this.height,
    this.width,
  });

  factory Attachment.fromMap(Map<String, dynamic> json) {
    String mimeType = json["mimeType"];
    if ((json['transferName'] as String).endsWith(".caf")) {
      mimeType = "audio/caf";
    }
    return new Attachment(
      id: json.containsKey("ROWID") ? json["ROWID"] : null,
      originalROWID:
          json.containsKey("originalROWID") ? json["originalROWID"] : null,
      guid: json["guid"],
      uti: json["uti"],
      mimeType: mimeType,
      transferState: json['transferState'].toString(),
      isOutgoing: (json["isOutgoing"] is bool)
          ? json['isOutgoing']
          : ((json['isOutgoing'] == 1) ? true : false),
      transferName: json['transferName'],
      totalBytes: json['totalBytes'] is int ? json['totalBytes'] : 0,
      isSticker: (json["isSticker"] is bool)
          ? json['isSticker']
          : ((json['isSticker'] == 1) ? true : false),
      hideAttachment: (json["hideAttachment"] is bool)
          ? json['hideAttachment']
          : ((json['hideAttachment'] == 1) ? true : false),
      blurhash: json.containsKey("blurhash") ? json["blurhash"] : null,
      height: json.containsKey("height") ? json["height"] : 0,
      width: json.containsKey("width") ? json["width"] : 0,
    );
  }

  Future<Attachment> save(Message message) async {
    final Database db = await DBProvider.db.database;

    // Try to find an existing attachment before saving it
    Attachment existing = await Attachment.findOne({"guid": this.guid});
    if (existing != null) {
      this.id = existing.id;
    }

    // If it already exists, update it
    if (existing == null) {
      // Remove the ID from the map for inserting
      var map = this.toMap();
      if (map.containsKey("ROWID")) {
        map.remove("ROWID");
      }
      if (map.containsKey("participants")) {
        map.remove("participants");
      }

      this.id = await db.insert("attachment", map);

      if (this.id != null && message.id != null) {
        await db.insert("attachment_message_join",
            {"attachmentId": this.id, "messageId": message.id});
      }
    }

    return this;
  }

  Future<Attachment> update() async {
    final Database db = await DBProvider.db.database;

    Map<String, dynamic> params = {
      "width": this.width,
      "height": this.height,
    };

    if (this.originalROWID != null) {
      params["originalROWID"] = this.originalROWID;
    }

    if (this.id != null) {
      await db.update("attachment", params,
          where: "ROWID = ?", whereArgs: [this.id]);
    }

    return this;
  }

  static Future<Attachment> replaceAttachment(
      String oldGuid, Attachment newAttachment) async {
    final Database db = await DBProvider.db.database;
    Attachment existing = await Attachment.findOne({"guid": oldGuid});
    if (existing == null) {
      throw ("Old GUID does not exist!");
    }

    Map<String, dynamic> params = newAttachment.toMap();
    if (params.containsKey("ROWID")) {
      params.remove("ROWID");
    }
    if (params.containsKey("width")) {
      params.remove("width");
    }
    if (params.containsKey("height")) {
      params.remove("height");
    }

    await db.update("attachment", params,
        where: "ROWID = ?", whereArgs: [existing.id]);
    String appDocPath = SettingsManager().appDocDir.path;
    String pathName = "$appDocPath/attachments/$oldGuid";
    Directory directory = Directory(pathName);
    await directory.rename("$appDocPath/attachments/${newAttachment.guid}");
    newAttachment.id = existing.id;
    newAttachment.width = existing.width;
    newAttachment.height = existing.height;
    return newAttachment;
  }

  static Future<Attachment> findOne(Map<String, dynamic> filters) async {
    final Database db = await DBProvider.db.database;

    List<String> whereParams = [];
    filters.keys.forEach((filter) => whereParams.add('$filter = ?'));
    List<dynamic> whereArgs = [];
    filters.values.forEach((filter) => whereArgs.add(filter));
    var res = await db.query("attachment",
        where: whereParams.join(" AND "), whereArgs: whereArgs, limit: 1);

    if (res.isEmpty) {
      return null;
    }

    return Attachment.fromMap(res.elementAt(0));
  }

  static Future<List<Attachment>> find(
      [Map<String, dynamic> filters = const {}]) async {
    final Database db = await DBProvider.db.database;

    List<String> whereParams = [];
    filters.keys.forEach((filter) => whereParams.add('$filter = ?'));
    List<dynamic> whereArgs = [];
    filters.values.forEach((filter) => whereArgs.add(filter));

    var res = await db.query("attachment",
        where: (whereParams.length > 0) ? whereParams.join(" AND ") : null,
        whereArgs: (whereArgs.length > 0) ? whereArgs : null);
    return (res.isNotEmpty)
        ? res.map((c) => Attachment.fromMap(c)).toList()
        : [];
  }

  static flush() async {
    final Database db = await DBProvider.db.database;
    await db.delete("attachment");
  }

  getFriendlySize({decimals: 2}) {
    double size = (this.totalBytes / 1024000.0);
    String postfix = "MB";
    if (size < 1) {
      size = size * 1024;
      postfix = "KB";
    } else if (size > 1024) {
      size = size / 1024;
      postfix = "GB";
    }

    return "${size.toStringAsFixed(decimals)} $postfix";
  }

  bool get hasValidSize =>
      width != null && height != null && width != 0 && height != 0;

  String get mimeStart {
    if (this.mimeType == null) return null;
    String _mimeType = this.mimeType;
    _mimeType = _mimeType.substring(0, _mimeType.indexOf("/"));
    return _mimeType;
  }

  Future<Attachment> updateDimensions(Uint8List data) async {
    if (mimeType == "image/gif") {
      Size size = getGifDimensions(data);

      if (size.width != 0 && size.height != 0) {
        width = size.width.toInt();
        height = size.height.toInt();
        await update();
      }
    } else if (mimeStart == "image" || mimeStart == "video") {
      IMG.Size size = IMG.ImageSizeGetter.getSize(IMG.MemoryInput(data));
      if (size.width != 0 && size.height != 0) {
        width = size.width;
        height = size.height;
        await update();
      }
    } else {
      width = null;
      height = null;
      await update();
    }
    return this;
  }

  static Future<int> countForChat(Chat chat) async {
    final Database db = await DBProvider.db.database;
    if (chat == null || chat.id == null) return 0;

    String query = ("SELECT"
        " count(attachment.ROWID) AS count"
        " FROM attachment"
        " JOIN attachment_message_join AS amj ON amj.attachmentId = attachment.ROWID"
        " JOIN message ON amj.messageId = message.ROWID"
        " JOIN chat_message_join AS cmj ON cmj.messageId = message.ROWID"
        " JOIN chat ON chat.ROWID = cmj.chatId"
        " WHERE chat.ROWID = ? AND attachment.mimeType IS NOT NULL");

    // Execute the query
    var res = await db.rawQuery("$query;", [chat.id]);
    if (res == null || res.length == 0) return 0;

    return res[0]["count"];
  }

  Map<String, dynamic> toMap() => {
        "ROWID": id,
        "originalROWID": originalROWID,
        "guid": guid,
        "uti": uti,
        "mimeType": mimeType,
        "transferState": transferState,
        "isOutgoing": isOutgoing ? 1 : 0,
        "transferName": transferName,
        "totalBytes": totalBytes,
        "isSticker": isSticker ? 1 : 0,
        "hideAttachment": hideAttachment ? 1 : 0,
        "blurhash": blurhash,
        "height": height,
        "width": width,
      };
}
