import 'package:bluebubbles/utils/logger.dart';
import 'package:path/path.dart';
import 'package:universal_io/io.dart';

void copyDirectory(Directory source, Directory destination) => source.listSync(recursive: false).forEach((element) async {
  if (element is Directory) {
    Directory newDirectory = Directory(join(destination.absolute.path, basename(element.path)));
    newDirectory.createSync();
    Logger.info("Created new directory ${basename(element.path)}");

    copyDirectory(element.absolute, newDirectory);
  } else if (element is File) {
    element.copySync(join(destination.path, basename(element.path)));
    Logger.info("Created file ${basename(element.path)}");
  }
});