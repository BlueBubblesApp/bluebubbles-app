import 'dart:convert';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/html/message.dart';
import 'package:bluebubbles/models/html/objectbox.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:mime_type/mime_type.dart';

class Attachment {
  int? id;
  int? originalROWID;
  String? guid;
  String? uti;
  String? mimeType;
  bool? isOutgoing;
  String? transferName;
  int? totalBytes;
  int? height;
  int? width;
  Uint8List? bytes;
  String? webUrl;
  Map<String, dynamic>? metadata;
  bool hasLivePhoto;

  final message = ToOne<Message>();

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
    this.bytes,
    this.webUrl,
    this.hasLivePhoto = false,
  });

  factory Attachment.fromMap(Map<String, dynamic> json) {
    String? mimeType = json["mimeType"];
    if (json["uti"] == "com.apple.coreaudio_format" || json['transferName'].toString().endsWith(".caf")) {
      mimeType = "audio/caf";
    }

    // Load the metadata
    var metadata = json["metadata"];
    if (metadata is String && metadata.isNotEmpty) {
      try {
        metadata = jsonDecode(metadata);
      } catch (_) {}
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
      metadata: metadata is String ? null : metadata,
      hasLivePhoto: json["hasLivePhoto"] ?? false,
    );
  }

  /// save a new attachment or update an existing attachment on disk
  /// [message] is used to create a link between the attachment and message,
  /// when provided
  Attachment save(Message? message) {
    return this;
  }

  /// Save many attachments at once. [map] is used to establish a link between
  /// the message and its attachments.
  static void bulkSave(Map<Message, List<Attachment>> map) {
    return;
  }

  /// replaces a temporary attachment with the new one from the server
  static Attachment replaceAttachment(String? oldGuid, Attachment newAttachment) {
    return newAttachment;
  }

  /// find an attachment by its guid
  static Attachment? findOne(String guid) {
    return null;
  }

  /// Find all attachments matching a specified condition, or all attachments
  /// if no condition is provided
  static List<Attachment> find({dynamic cond}) {
    return [];
  }

  /// Delete an attachment and remove all instances of that attachment in the DB
  static void delete(String guid) {}

  String getFriendlySize({decimals = 2}) {
    return (totalBytes ?? 0.0).toDouble().getFriendlySize();
  }

  bool get hasValidSize => (width ?? 0) > 0 && (height ?? 0) > 0;

  double get aspectRatio => hasValidSize ? (_isPortrait && height! < width! ?  (height! / width!).abs() : (width! / height!).abs()) : 0.78;

  String? get mimeStart => mimeType?.split("/").first;

  static String get baseDirectory => "${fs.appDocDir.path}/attachments";

  String get directory => "$baseDirectory/$guid";

  String get path => "$directory/$transferName";

  String get convertedPath => "$path.jpg";

  bool get existsOnDisk => false;

  Future<bool> get existsOnDiskAsync async => false;

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
    if (attachment2.hasLivePhoto) {
      attachment1.hasLivePhoto = attachment2.hasLivePhoto;
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
    "hasLivePhoto": hasLivePhoto,
  };

  bool  get _isPortrait {
    if (metadata?['orientation'] == '1') return true;
    if (metadata?['orientation'] == 1) return true;
    if (metadata?['orientation'] == 'portrait') return true;
    if (metadata?['Image Orientation']?.contains("90") ?? false) return true;
    return false;
  }
}
