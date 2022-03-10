import 'dart:convert';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/chat_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/objectbox.g.dart';
import 'package:bluebubbles/repository/models/io/message.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:mime_type/mime_type.dart';
// (needed when generating objectbox model code)
// ignore: unnecessary_import
import 'package:objectbox/objectbox.dart';
import 'package:universal_io/io.dart';

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

  final message = ToOne<Message>();

  String? get dbMetadata {
    return (metadata == null ? null : jsonEncode(metadata));
  }

  set dbMetadata(String? value) {
    metadata = (value == null) ? null : jsonDecode(value) as Map<String, dynamic>;
  }

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

  /// Attachment exists on disk. Always returns false on Web.
  ///
  /// Avoid calling this method from intensive tasks as it is a synchronous read.
  bool get existsOnDisk {
    if (kIsWeb) return false;
    File attachment = File(AttachmentHelper.getAttachmentPath(this));
    return attachment.existsSync();
  }

  /// Get the orientation of the photo by parsing its metadata. If no metadata,
  /// 'portrait' is returned.
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

  /// Convert JSON to [Attachment]
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

  /// Save a new attachment or update an existing attachment on disk
  /// [message] is used to create a link between the attachment and message,
  /// when provided
  Attachment save(Message? message) {
    if (kIsWeb) return this;
    store.runInTransaction(TxMode.write, () {
      /// Find an existing attachment and update the attachment ID if applicable
      Attachment? existing = Attachment.findOne(guid!);
      if (existing != null) {
        id = existing.id;
      }
      try {
        /// store the attachment and add the link between the message and
        /// attachment
        if (message?.id != null) {
          this.message.target = message;
        }

        id = attachmentBox.put(this);
      } on UniqueViolationException catch (_) {}
    });
    return this;
  }

  /// Save many attachments at once. [map] is used to establish a link between
  /// the message and its attachments.
  static void bulkSave(Map<Message, List<Attachment>> map) {
    return store.runInTransaction(TxMode.write, () {
      /// convert List<List<Attachment>> into just List<Attachment> (flatten it)
      final attachments = map.values.expand((element) => element).toList();

      /// find existing attachments
      List<Attachment> existingAttachments =
          Attachment.find(cond: Attachment_.guid.oneOf(attachments.map((e) => e.guid!).toList()));

      /// map existing attachment IDs to the attachments to save, if applicable
      for (Attachment a in attachments) {
        final existing = existingAttachments.firstWhereOrNull((e) => e.guid == a.guid);
        if (existing != null) {
          a.id = existing.id;
        }
      }
      try {
        /// store the attachments and update their ids
        final ids = attachmentBox.putMany(attachments);
        for (int i = 0; i < attachments.length; i++) {
          attachments[i].id = ids[i];
        }

        /// convert the map of messages and lists into an [AttachmentMessageJoin]
        /// with some fancy list operations
        /*amJoinBox.putMany(map.entries
            .map((e) => e.value.map((e2) => AttachmentMessageJoin(attachmentId: e2.id ?? 0, messageId: e.key.id ?? 0)))
            .expand((element) => element)
            .toList()
          ..removeWhere((element) => element.attachmentId == 0 || element.messageId == 0));*/
      } on UniqueViolationException catch (_) {}
    });
  }

  /// replaces a temporary attachment with the new one from the server
  static Attachment replaceAttachment(String? oldGuid, Attachment newAttachment) {
    if (kIsWeb) return newAttachment;
    Attachment? existing = Attachment.findOne(oldGuid!);
    if (existing == null) {
      throw ("Old GUID does not exist!");
    }
    // update current chat image data to prevent the image or video thumbnail from reloading
    final data = ChatManager().activeChat?.getImageData(existing);
    if (data != null) {
      ChatManager().activeChat?.clearImageData(existing);
      ChatManager().activeChat?.saveImageData(data, newAttachment);
    }
    // update values and save
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
    existing.save(null);
    // change the directory path
    String appDocPath = SettingsManager().appDocDir.path;
    String pathName = "$appDocPath/attachments/$oldGuid";
    Directory directory = Directory(pathName);
    directory.renameSync("$appDocPath/attachments/${newAttachment.guid}");
    // grab values from existing
    newAttachment.id = existing.id;
    newAttachment.width = existing.width;
    newAttachment.height = existing.height;
    newAttachment.metadata = existing.metadata;
    return newAttachment;
  }

  /// find an attachment by its guid
  static Attachment? findOne(String guid) {
    if (kIsWeb) return null;
    final query = attachmentBox.query(Attachment_.guid.equals(guid)).build();
    query.limit = 1;
    final result = query.findFirst();
    query.close();
    return result;
  }

  /// Find all attachments matching a specified condition, or all attachments
  /// if no condition is provided
  static List<Attachment> find({Condition<Attachment>? cond}) {
    final query = attachmentBox.query(cond).build();
    return query.find();
  }

  /// clear the attachment DB
  static void flush() {
    if (!kIsWeb) {
      attachmentBox.removeAll();
    }
  }

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
