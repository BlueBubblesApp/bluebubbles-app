import 'package:image_size_getter/image_size_getter.dart';

export 'package:bluebubbles/repository/models/io/attachment.dart'
    if (dart.library.html) 'package:bluebubbles/repository/models/html/attachment.dart';
export 'package:bluebubbles/repository/models/io/chat.dart'
    if (dart.library.html) 'package:bluebubbles/repository/models/html/chat.dart';
export 'package:bluebubbles/repository/models/io/contact.dart'
  if (dart.library.html) 'package:bluebubbles/repository/models/html/contact.dart';
export 'package:bluebubbles/repository/models/io/fcm_data.dart'
    if (dart.library.html) 'package:bluebubbles/repository/models/html/fcm_data.dart';
export 'package:bluebubbles/repository/models/io/handle.dart'
    if (dart.library.html) 'package:bluebubbles/repository/models/html/handle.dart';
export 'package:bluebubbles/repository/models/io/join_tables.dart'
    if (dart.library.html) 'package:bluebubbles/repository/models/html/join_tables.dart';
export 'package:bluebubbles/repository/models/io/js.dart'
    if (dart.library.html) 'package:bluebubbles/repository/models/html/js.dart';
export 'package:bluebubbles/repository/models/io/launch_at_startup.dart'
    if (dart.library.html) 'package:bluebubbles/repository/models/html/launch_at_startup.dart';
export 'package:bluebubbles/repository/models/io/message.dart'
    if (dart.library.html) 'package:bluebubbles/repository/models/html/message.dart';
export 'package:bluebubbles/repository/models/io/scheduled.dart'
    if (dart.library.html) 'package:bluebubbles/repository/models/html/scheduled.dart';
export 'package:bluebubbles/repository/models/io/theme.dart'
    if (dart.library.html) 'package:bluebubbles/repository/models/html/theme.dart';
export 'package:bluebubbles/repository/models/io/theme_entry.dart'
  if (dart.library.html) 'package:bluebubbles/repository/models/html/theme_entry.dart';
export 'package:bluebubbles/repository/models/io/theme_object.dart'
  if (dart.library.html) 'package:bluebubbles/repository/models/html/theme_object.dart';
export 'package:bluebubbles/repository/models/io/giphy.dart'
    if (dart.library.html) 'package:bluebubbles/repository/models/html/giphy.dart';
export 'package:bluebubbles/repository/models/platform_file.dart';
export 'package:bluebubbles/repository/models/settings.dart';
export 'package:bluebubbles/repository/models/attributed_body.dart';
export 'package:bluebubbles/repository/models/structured_name.dart';

class AsyncInput extends AsyncImageInput {
  AsyncInput(this._input);

  /// The input data of [ImageInput].
  final ImageInput _input;

  @override
  Future<bool> supportRangeLoad() async {
    return true;
  }

  @override
  Future<bool> exists() async {
    return _input.exists();
  }

  @override
  Future<List<int>> getRange(int start, int end) async {
    return _input.getRange(start, end);
  }

  @override
  Future<int> get length async => _input.length;

  @override
  Future<HaveResourceImageInput> delegateInput() async {
    return HaveResourceImageInput(innerInput: _input);
  }
}
