import 'dart:typed_data';

import 'package:fast_contacts/fast_contacts.dart';
import 'package:get/get.dart';
import 'package:image_size_getter/image_size_getter.dart';
//ignore: implementation_imports
import 'package:image_size_getter/src/utils/file_utils.dart';

class Contact {
  Contact({
    required this.id,
    required this.displayName,
    this.phones = const [],
    this.emails = const [],
    this.structuredName,
    Uint8List? avatarBytes,
  }) {
    avatar.value = avatarBytes;
  }

  String id;
  String displayName;
  List<String> phones;
  List<String> emails;
  StructuredName? structuredName;
  final Rxn<Uint8List> avatar = Rxn<Uint8List>();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'phones': phones,
      'emails': emails,
    };
  }

  factory Contact.fromMap(Map<String, dynamic> map) {
    // backwards compatibility with old contacts plugin
    if (map['phones'].isNotEmpty && map['phones'][0] is Map<String, dynamic>) {
      map['phones'] = map['phones'].map((e) => e['value'] ?? "").toList();
    }
    if (map['emails'].isNotEmpty && map['emails'][0] is Map<String, dynamic>) {
      map['emails'] = map['emails'].map((e) => e['value'] ?? "").toList();
    }
    return Contact(
      id: (map['id'] ?? map['identifier']) as String,
      displayName: map['displayName'] as String,
      phones: map['phones'].cast<String>(),
      emails: map['emails'].cast<String>(),
    );
  }
}

class AsyncFileInput extends AsyncImageInput {
  final dynamic file;

  AsyncFileInput(this.file);

  @override
  Future<List<int>> getRange(int start, int end) async {
    final utils = FileUtils(file);
    return await utils.getRange(start, end);
  }

  @override
  Future<int> get length async => await file.length();

  @override
  Future<bool> exists() async {
    return await file.exists();
  }
}

class AsyncMemoryInput extends AsyncImageInput {
  final Uint8List bytes;
  const AsyncMemoryInput(this.bytes);

  factory AsyncMemoryInput.byteBuffer(ByteBuffer buffer) {
    return AsyncMemoryInput(buffer.asUint8List());
  }

  @override
  Future<List<int>> getRange(int start, int end) async {
    return bytes.sublist(start, end);
  }

  @override
  Future<int> get length async => bytes.length;

  @override
  Future<bool> exists() async {
    return bytes.isNotEmpty;
  }
}