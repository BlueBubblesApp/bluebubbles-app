import 'package:bluebubbles/models/global/platform_file.dart';
import 'package:universal_io/io.dart';

Future<PlatformFile?> loadPathAsFile(String path) async {
  final file = File(path);
  if (!(await file.exists())) return null;

  final bytes = await file.readAsBytes();
  return PlatformFile(
    name: file.path.split("/").last,
    bytes: bytes,
    size: bytes.length,
    path: path,
  );
}