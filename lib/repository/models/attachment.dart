import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/objectbox.g.dart';
import 'package:bluebubbles/repository/models/join_tables.dart';
import 'package:flutter/foundation.dart';
import 'package:objectbox/objectbox.dart';
import 'package:universal_io/io.dart';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:mime_type/mime_type.dart';


import '../database.dart';

Attachment attachmentFromJson(String str) {
  final jsonData = json.decode(str);
  return Attachment.fromMap(jsonData);
}

String attachmentToJson(Attachment data) {
  final dyn = data.toMap();
  return json.encode(dyn);
}

@Entity()
class Attachment {
  int? id;
  int? originalROWID;
  @Unique()
  String? guid;
  String? uti;
  String? mimeType;
  String? transferState;
  bool? isOutgoing;
  String? transferName;
  int? totalBytes;
  bool? isSticker;
  bool? hideAttachment;
  String? blurhash;
  int? height;
  int? width;
  Map<String, dynamic>? metadata;
  Uint8List? bytes;
  String? webUrl;

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
    this.metadata,
    this.bytes,
    this.webUrl,
  });

  bool get existsOnDisk {
    if (kIsWeb) return false;
    File attachment = new File(AttachmentHelper.getAttachmentPath(this));
    return attachment.existsSync();
  }

  String get orientation {
    String orientation = 'portrait'; // Default
    if (this.metadata == null) return orientation;
    // This key is from FlutterNativeImage
    if (this.metadata!.containsKey('orientation') &&
        (this.metadata!['orientation'].toString().toLowerCase().contains('landscape') ||
            this.metadata!['orientation'].toString() == '0')) {
      orientation = 'landscape';
      // This key is from the Exif loader
    } else if (this.metadata!.containsKey('Image Orientation') &&
        (this.metadata!['Image Orientation'].toString().toLowerCase().contains('horizontal') ||
            this.metadata!['orientation'].toString() == '0')) {
      orientation = 'landscape';
    }

    return orientation;
  }

  factory Attachment.fromMap(Map<String, dynamic> json) {
    String? mimeType = json["mimeType"];
    if ((json.containsKey("uti") && json["uti"] == "com.apple.coreaudio_format") ||
        (json.containsKey("transferName") && (json['transferName'] ?? "").endsWith(".caf"))) {
      mimeType = "audio/caf";
    }

    // Load the metadata
    dynamic metadata = json.containsKey("metadata") ? json["metadata"] : null;
    if (!isNullOrEmpty(metadata)!) {
      // If the metadata is a string, convert it to JSON
      if (metadata is String) {
        try {
          metadata = jsonDecode(metadata);
        } catch (ex) {}
      }
    }

    var data = new Attachment(
      id: json.containsKey("ROWID") ? json["ROWID"] : null,
      originalROWID: json.containsKey("originalROWID") ? json["originalROWID"] : null,
      guid: json["guid"],
      uti: json["uti"],
      mimeType: mimeType ?? mime(json['transferName']),
      transferState: json['transferState'].toString(),
      isOutgoing: (json["isOutgoing"] is bool) ? json['isOutgoing'] : ((json['isOutgoing'] == 1) ? true : false),
      transferName: json['transferName'],
      totalBytes: json['totalBytes'] is int ? json['totalBytes'] : 0,
      isSticker: (json["isSticker"] is bool) ? json['isSticker'] : ((json['isSticker'] == 1) ? true : false),
      hideAttachment:
          (json["hideAttachment"] is bool) ? json['hideAttachment'] : ((json['hideAttachment'] == 1) ? true : false),
      blurhash: json.containsKey("blurhash") ? json["blurhash"] : null,
      height: json.containsKey("height") ? json["height"] : 0,
      width: json.containsKey("width") ? json["width"] : 0,
      metadata: metadata is String ? null : metadata,
    );

    // Adds fallback getter for the ID
    if (data.id == null) {
      data.id = json.containsKey("id") ? json["id"] : null;
    }

    return data;
  }

  Future<Attachment> save(Message? message) async {
    Attachment? existing = await Attachment.findOne(this.guid!);
    if (existing != null) {
      this.id = existing.id;
    }
    try {
      attachmentBox.put(this);
      if (this.id != null && message?.id != null)
        amJoinBox.put(AttachmentMessageJoin(attachmentId: this.id!, messageId: message!.id!));
    } on UniqueViolationException catch (_) {}
    /*final Database? db = await DBProvider.db.database;

    // Try to find an existing attachment before saving it
    Attachment? existing = await Attachment.findOne({"guid": this.guid});
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

      this.id = (await db?.insert("attachment", map)) ?? id;

      if (this.id != null && message!.id != null) {
        await db?.insert("attachment_message_join", {"attachmentId": this.id, "messageId": message.id});
      }
    }*/

    return this;
  }

  Future<Attachment> update() async {
    /*final Database? db = await DBProvider.db.database;

    Map<String, dynamic> params = {
      "width": this.width,
      "height": this.height,
      // If it's null or empty, save it as null
      "metadata": isNullOrEmpty(this.metadata)! ? null : jsonEncode(this.metadata)
    };

    if (this.originalROWID != null) {
      params["originalROWID"] = this.originalROWID;
    }

    if (this.id != null) {
      await db?.update("attachment", params, where: "ROWID = ?", whereArgs: [this.id]);
    }*/
    this.save(null);

    return this;
  }

  static Future<Attachment> replaceAttachment(String? oldGuid, Attachment newAttachment) async {
    //final Database? db = await DBProvider.db.database;
    Attachment? existing = await Attachment.findOne(oldGuid!);
    if (existing == null) {
      throw ("Old GUID does not exist!");
    }
    existing.guid = newAttachment.guid;
    existing.originalROWID = newAttachment.originalROWID;
    existing.uti = newAttachment.uti;
    existing.mimeType = newAttachment.mimeType ?? existing.mimeType;
    existing.transferState = newAttachment.transferState;
    existing.isOutgoing = newAttachment.isOutgoing;
    existing.transferName = newAttachment.transferName;
    existing.totalBytes = newAttachment.totalBytes;
    existing.isSticker = newAttachment.isSticker;
    existing.hideAttachment = newAttachment.hideAttachment;
    existing.blurhash = newAttachment.blurhash;
    existing.bytes = newAttachment.bytes;
    existing.webUrl = newAttachment.webUrl;
    attachmentBox.put(existing);
    /*Map<String, dynamic> params = newAttachment.toMap();
    if (params.containsKey("ROWID")) {
      params.remove("ROWID");
    }
    if (params.containsKey("width")) {
      params.remove("width");
    }
    if (params.containsKey("height")) {
      params.remove("height");
    }
    if (params.containsKey("metadata")) {
      params.remove("metadata");
    }

    // Don't override the mimetype if it's null
    if (newAttachment.mimeType == null) {
      params.remove("mimeType");
    }

    await db?.update("attachment", params, where: "ROWID = ?", whereArgs: [existing.id]);*/
    String appDocPath = SettingsManager().appDocDir.path;
    String pathName = "$appDocPath/attachments/$oldGuid";
    Directory directory = Directory(pathName);
    await directory.rename("$appDocPath/attachments/${newAttachment.guid}");
    newAttachment.id = existing.id;
    newAttachment.width = existing.width;
    newAttachment.height = existing.height;
    newAttachment.metadata = existing.metadata;
    return newAttachment;
  }

  static Future<Attachment?> findOne(String guid) async {
    final query = attachmentBox.query(Attachment_.guid.equals(guid)).build();
    query..limit = 1;
    final result = query.findFirst();
    query.close();
    return result;
    /*final Database? db = await DBProvider.db.database;
    if (db == null) return null;
    List<String> whereParams = [];
    filters.keys.forEach((filter) => whereParams.add('$filter = ?'));
    List<dynamic> whereArgs = [];
    filters.values.forEach((filter) => whereArgs.add(filter));
    var res = await db.query("attachment", where: whereParams.join(" AND "), whereArgs: whereArgs, limit: 1);

    if (res.isEmpty) {
      return null;
    }

    return Attachment.fromMap(res.elementAt(0));*/
  }

  static flush() async {
    attachmentBox.removeAll();
    /*final Database? db = await DBProvider.db.database;
    await db?.delete("attachment");*/
  }

  getFriendlySize({decimals: 2}) {
    double size = (this.totalBytes! / 1024000.0);
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

  bool get hasValidSize => (width ?? 0) > 0 && (height ?? 0) > 0;

  String? get mimeStart {
    if (this.mimeType == null) return null;
    String _mimeType = this.mimeType!;
    _mimeType = _mimeType.substring(0, _mimeType.indexOf("/"));
    return _mimeType;
  }

  String getPath() {
    String? fileName = this.transferName;
    String appDocPath = SettingsManager().appDocDir.path;
    String pathName = "$appDocPath/attachments/${this.guid}/$fileName";
    return pathName;
  }

  String getCompressedPath() {
    return "${this.getPath()}.${SettingsManager().compressionQuality}.compressed";
  }

  Map<String, dynamic> toMap() => {
        "ROWID": id,
        "originalROWID": originalROWID,
        "guid": guid,
        "uti": uti,
        "mimeType": mimeType,
        "transferState": transferState,
        "isOutgoing": isOutgoing! ? 1 : 0,
        "transferName": transferName,
        "totalBytes": totalBytes,
        "isSticker": isSticker! ? 1 : 0,
        "hideAttachment": hideAttachment! ? 1 : 0,
        "blurhash": blurhash,
        "height": height,
        "width": width,
        "metadata": jsonEncode(metadata),
      };
}
