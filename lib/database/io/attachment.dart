import 'dart:convert';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/utils/deep_map_normalize.dart';
import 'package:bluebubbles/generated/objectbox.g.dart';
import 'package:bluebubbles/database/io/message.dart';
import 'package:bluebubbles/services/backend/descriptors/attachment_query_descriptor.dart';
import 'package:bluebubbles/services/backend/interfaces/attachment_interface.dart';
import 'package:bluebubbles/services/services.dart';
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

  @Index(type: IndexType.value)
  @Unique()
  String? guid;

  String? uti;
  String? mimeType;
  bool? isOutgoing;
  String? transferName;
  int? totalBytes;
  int? height;
  int? width;
  @Transient()
  Uint8List? bytes;
  String? webUrl;
  bool hasLivePhoto;
  bool isDownloaded;

  final message = ToOne<Message>();

  Map<String, dynamic>? metadata;

  Map<String, dynamic>? exif;

  String? get dbMetadata => metadata == null ? null : jsonEncode(metadata);
  set dbMetadata(String? json) => metadata = json == null ? null : asStringDynamicMap(jsonDecode(json));

  Attachment({
    this.id,
    this.originalROWID,
    this.guid,
    this.uti,
    this.mimeType,
    this.isOutgoing,
    this.transferName,
    this.totalBytes,
    this.height,
    this.width,
    this.metadata,
    this.exif,
    this.bytes,
    this.webUrl,
    this.hasLivePhoto = false,
    this.isDownloaded = false,
  });

  /// Convert JSON to [Attachment]
  factory Attachment.fromMap(Map<String, dynamic> json) {
    json = asStringDynamicMapRequired(json);

    String? mimeType = json["mimeType"];
    if (json["uti"] == "com.apple.coreaudio_format" || json['transferName'].toString().endsWith(".caf")) {
      mimeType = "audio/caf";
    }

    Map<String, dynamic>? metadata;
    final rawMetadata = json["metadata"];
    if (rawMetadata is String && rawMetadata.isNotEmpty) {
      try {
        metadata = asStringDynamicMap(jsonDecode(rawMetadata));
      } catch (_) {}
    } else {
      metadata = asStringDynamicMap(rawMetadata);
    }

    Map<String, dynamic>? exif;
    final rawExif = json["exif"];
    if (rawExif is String && rawExif.isNotEmpty) {
      try {
        exif = asStringDynamicMap(jsonDecode(rawExif));
      } catch (_) {}
    } else {
      exif = asStringDynamicMap(rawExif);
    }

    return Attachment(
      id: json["ROWID"] ?? json["id"],
      originalROWID: json["originalROWID"],
      guid: json["guid"],
      uti: json["uti"],
      mimeType: mimeType ?? mime(json['transferName']),
      isOutgoing: json["isOutgoing"] == true,
      transferName: json['transferName'],
      totalBytes: json['totalBytes'] is int ? json['totalBytes'] : 0,
      height: json["height"] ?? 0,
      width: json["width"] ?? 0,
      metadata: metadata,
      exif: exif,
      hasLivePhoto: json["hasLivePhoto"] ?? false,
      isDownloaded: json["isDownloaded"] ?? false,
    );
  }

  Future<Attachment> saveAsync(Message? message) async {
    if (kIsWeb) return this;

    final result = await AttachmentInterface.saveAttachmentAsync(
      attachmentData: toMap(),
      messageData: message?.toMap(),
    );

    id = result.id;
    return this;
  }

  static Future<void> bulkSaveAsync(Map<Message, List<Attachment>> map) async {
    // Convert the map to serializable format
    Map<Map<String, dynamic>, List<Map<String, dynamic>>> mapData = {};
    for (var entry in map.entries) {
      mapData[entry.key.toMap()] = entry.value.map((e) => e.toMap()).toList();
    }

    await AttachmentInterface.bulkSaveAttachmentsAsync(mapData: mapData);
  }

  /// replaces a temporary attachment with the new one from the server (async version)
  /// Note: This must be called from the main thread to access cm/cvc services
  static Future<Attachment> replaceAttachmentAsync(String? oldGuid, Attachment newAttachment) async {
    if (kIsWeb) return newAttachment;

    Attachment? existing = await Attachment.findOneAsync(oldGuid!);
    if (existing == null) {
      return Future.error("Old GUID ($oldGuid) does not exist!");
    }

    // Handle cm/cvc services on main thread BEFORE calling isolate
    if (ChatsSvc.activeChat != null) {
      // Image caching is now handled by Flutter's image cache automatically
    }

    // Call the isolate-safe database operations
    final updatedAttachment = await AttachmentInterface.replaceAttachmentAsync(
      oldGuid: oldGuid,
      newAttachmentData: newAttachment.toMap(),
    );

    // Handle file system operations on main thread AFTER isolate call
    String appDocPath = FilesystemSvc.appDocDir.path;
    String pathName = "$appDocPath/attachments/$oldGuid";
    Directory directory = Directory(pathName);

    if (directory.existsSync()) {
      final newDirPath = "$appDocPath/attachments/${newAttachment.guid}";
      await directory.rename(newDirPath);

      // After the directory rename the file inside still has its old name (the temp transferName).
      // If the server assigned a different transferName, rename the file to match so that
      // attachment.path resolves correctly and the file won't be re-downloaded.
      if (newAttachment.transferName != null) {
        final expectedPath = newAttachment.path; // uses new guid + new transferName
        if (!File(expectedPath).existsSync()) {
          final files = Directory(newDirPath).listSync().whereType<File>().toList();
          if (files.isNotEmpty) {
            await files.first.rename(expectedPath);
          }
        }
      }
    }

    // Update newAttachment with values from result
    newAttachment.id = updatedAttachment.id;
    newAttachment.width = updatedAttachment.width;
    newAttachment.height = updatedAttachment.height;
    newAttachment.metadata = updatedAttachment.metadata;
    newAttachment.exif = updatedAttachment.exif;
    // Preserve isDownloaded from the DB record — the action layer does not overwrite it,
    // so if prepAttachment set it to true the value survives the GUID swap.
    newAttachment.isDownloaded = updatedAttachment.isDownloaded;

    return newAttachment;
  }

  static Future<Attachment?> findOneAsync(String guid) async {
    if (kIsWeb) return null;
    return await AttachmentInterface.findOneAttachmentAsync(guid: guid);
  }

  static Future<List<Attachment>> findAsync({
    AttachmentQueryDescriptor? queryDescriptor,
  }) async {
    if (kIsWeb) return [];
    return await AttachmentInterface.findAttachmentsAsync(queryDescriptor: queryDescriptor);
  }

  static Future<void> deleteAsync(String guid) async {
    if (kIsWeb) return;

    await AttachmentInterface.deleteAttachmentAsync(guid: guid);
  }

  String getFriendlySize({int decimals = 2}) {
    return (totalBytes ?? 0.0).toDouble().getFriendlySize(decimals: decimals);
  }

  /// Returns the best available width for display purposes.
  /// Prefers the dedicated DB field; falls back to a `width` key in metadata
  /// (e.g. sent by the server before local dimension extraction runs).
  int? get displayWidth {
    if (width != null && width! > 0) return width;
    return (metadata?['width'] as num?)?.toInt();
  }

  /// Returns the best available height for display purposes.
  /// Prefers the dedicated DB field; falls back to a `height` key in metadata.
  int? get displayHeight {
    if (height != null && height! > 0) return height;
    return (metadata?['height'] as num?)?.toInt();
  }

  bool get hasValidSize => (displayWidth ?? 0) > 0 && (displayHeight ?? 0) > 0;

  double get aspectRatio => hasValidSize ? (displayWidth! / displayHeight!).abs() : 0.78;

  String? get mimeStart => mimeType?.split("/").first;

  static String get baseDirectory => FilesystemSvc.attachmentsPath;

  String get directory => "$baseDirectory/$guid";

  String get path {
    switch (Platform.operatingSystem) {
      case "windows":
        return "$directory/${"$transferName".replaceAll(RegExp(r'[<>:"/\|?*]'), "_")}";
      case "linux":
      case "macos":
        return "$directory/${"$transferName".replaceAll(RegExp(r'/'), "_")}";
      default:
        return "$directory/$transferName";
    }
  }

  String get convertedPath => "$path.png";

  bool get existsOnDisk => File(path).existsSync();

  Future<bool> get existsOnDiskAsync async => await File(path).exists();

  bool get canCompress => mimeStart == "image" && !mimeType!.contains("gif");

  static Attachment merge(Attachment attachment1, Attachment attachment2) {
    attachment1.id ??= attachment2.id;
    attachment1.bytes ??= attachment2.bytes;
    attachment1.guid ??= attachment2.guid;
    attachment1.height ??= attachment2.height;
    attachment1.width ??= attachment2.width;
    attachment1.isOutgoing ??= attachment2.isOutgoing;
    attachment1.mimeType ??= attachment2.mimeType;
    attachment1.totalBytes ??= attachment2.totalBytes;
    attachment1.transferName ??= attachment2.transferName;
    attachment1.uti ??= attachment2.uti;
    attachment1.webUrl ??= attachment2.webUrl;
    attachment1.metadata = mergeTopLevelDicts(attachment1.metadata, attachment2.metadata);
    attachment1.exif = mergeTopLevelDicts(attachment1.exif, attachment2.exif);
    if (attachment2.hasLivePhoto) {
      attachment1.hasLivePhoto = attachment2.hasLivePhoto;
    }
    // Only overwrite isDownloaded if the new attachment is downloaded
    if (!attachment1.isDownloaded && attachment2.isDownloaded) {
      attachment1.isDownloaded = attachment2.isDownloaded;
    }
    if (!attachment1.message.hasValue) {
      attachment1.message.target = attachment2.message.target;
    }
    return attachment1;
  }

  Map<String, dynamic> toMap() => {
        "ROWID": id,
        "originalROWID": originalROWID,
        "guid": guid,
        "uti": uti,
        "mimeType": mimeType,
        "isOutgoing": isOutgoing!,
        "transferName": transferName,
        "totalBytes": totalBytes,
        "height": height,
        "width": width,
        "metadata": jsonEncode(metadata),
        "exif": jsonEncode(exif),
        "hasLivePhoto": hasLivePhoto,
        "isDownloaded": isDownloaded,
      };
}
