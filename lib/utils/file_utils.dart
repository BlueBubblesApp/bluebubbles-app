import 'package:bluebubbles/models/global/platform_file.dart';
import 'package:path/path.dart';
import 'package:universal_io/io.dart';

Future<PlatformFile?> loadPathAsFile(String path) async {
  final file = File(path);
  if (!(await file.exists())) return null;

  final bytes = await file.readAsBytes();
  return PlatformFile(
    name: basename(file.path),
    bytes: bytes,
    size: bytes.length,
    path: path,
  );
}