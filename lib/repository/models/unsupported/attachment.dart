import 'dart:typed_data';

import '../models.dart';

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

  bool get existsOnDisk => throw Exception("Unsupported Platform");

  String get orientation => throw Exception("Unsupported Platform");

  factory Attachment.fromMap(Map<String, dynamic> json) => throw Exception("Unsupported Platform");

  /// save a new attachment or update an existing attachment on disk
  /// [message] is used to create a link between the attachment and message,
  /// when provided
  Attachment save(Message? message) => throw Exception("Unsupported Platform");

  /// replaces a temporary attachment with the new one from the server
  static Attachment replaceAttachment(String? oldGuid, Attachment newAttachment) => throw Exception("Unsupported Platform");

  /// find an attachment by its guid
  static Attachment? findOne(String guid) => throw Exception("Unsupported Platform");

  /// clear the attachment DB
  static void flush() => throw Exception("Unsupported Platform");

  String getFriendlySize({decimals: 2}) => throw Exception("Unsupported Platform");

  bool get hasValidSize => throw Exception("Unsupported Platform");

  String? get mimeStart => throw Exception("Unsupported Platform");

  String getPath() => throw Exception("Unsupported Platform");

  String getCompressedPath() => throw Exception("Unsupported Platform");

  Map<String, dynamic> toMap() => throw Exception("Unsupported Platform");
}
