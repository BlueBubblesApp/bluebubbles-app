import 'dart:convert';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/html/message.dart';
import 'package:bluebubbles/repository/models/html/objectbox.dart';
import 'package:mime_type/mime_type.dart';

class Attachment {
  int? id;
  int? originalROWID;
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

  final message = ToOne<Message>();

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
    return false;
  }

  String get orientation {
    String orientation = 'portrait'; // Default
    if (metadata == null) return orientation;
    // This key is from FlutterNativeImage
    if (metadata!.containsKey('orientation') &&
        (metadata!['orientation'].toString().toLowerCase().contains('landscape') ||
            metadata!['orientation'].toString() == '0')) {
      orientation = 'landscape';
      // This key is from the Exif loader
    } else if (metadata!.containsKey('Image Orientation') &&
        (metadata!['Image Orientation'].toString().toLowerCase().contains('horizontal') ||
            metadata!['orientation'].toString() == '0')) {
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
        } catch (_) {}
      }
    }

    var data = Attachment(
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
    data.id ??= json.containsKey("id") ? json["id"] : null;

    return data;
  }

  /// save a new attachment or update an existing attachment on disk
  /// [message] is used to create a link between the attachment and message,
  /// when provided
  Attachment save(Message? message) {
    return this;
  }

  /// replaces a temporary attachment with the new one from the server
  static Attachment replaceAttachment(String? oldGuid, Attachment newAttachment) {
    return newAttachment;
  }

  /// find an attachment by its guid
  static Attachment? findOne(String guid) {
    return null;
  }

  /// clear the attachment DB
  static void flush() {}

  String getFriendlySize({decimals = 2}) {
    double size = ((totalBytes ?? 0) / 1024000.0);
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
    if (mimeType == null) return null;
    String _mimeType = mimeType!;
    _mimeType = _mimeType.substring(0, _mimeType.indexOf("/"));
    return _mimeType;
  }

  String getPath() {
    String? fileName = transferName;
    String appDocPath = SettingsManager().appDocDir.path;
    String pathName = "$appDocPath/attachments/$guid/$fileName";
    return pathName;
  }

  String getHeicToJpgPath() {
    return "${getPath()}.jpg";
  }

  String getCompressedPath() {
    return "${getPath()}.${SettingsManager().compressionQuality}.compressed";
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
