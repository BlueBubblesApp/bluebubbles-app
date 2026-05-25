import 'dart:io';

import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart' as fic;
import 'package:path/path.dart' as p;

class HeifConverter {
  static const _heifMimes = {'image/heic', 'image/heif', 'image/heic-sequence', 'image/heif-sequence'};
  static const _heifExts = {'heic', 'heif', 'hif'};

  static bool isHeif(String? mimeType, {String? filename}) {
    if (mimeType != null && _heifMimes.contains(mimeType.toLowerCase())) return true;
    if (filename != null && filename.contains('.')) {
      return _heifExts.contains(filename.split('.').last.toLowerCase());
    }
    return false;
  }

  static Future<String?> convertInPlace(String sourcePath) async {
    final src = File(sourcePath);
    if (!await src.exists()) return null;

    final dest = _swapExt(sourcePath, 'jpg');
    bool ok = false;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        ok = await _convertMobile(sourcePath, dest);
      } else if (Platform.isLinux) {
        ok = await _convertLinux(sourcePath, dest);
      } else if (Platform.isMacOS) {
        ok = await _convertMacOS(sourcePath, dest);
      }
    } catch (e, st) {
      Logger.error('HEIF decode threw', error: e, trace: st);
      return null;
    }

    if (!ok) return null;

    try {
      await src.delete();
      await File(dest).rename(sourcePath);
      return sourcePath;
    } catch (_) {
      return dest;
    }
  }

  static Future<bool> _convertMobile(String src, String dest) async {
    final bytes = await fic.FlutterImageCompress.compressWithFile(src, format: fic.CompressFormat.jpeg, quality: 92);
    if (bytes == null || bytes.isEmpty) return false;
    await File(dest).writeAsBytes(bytes);
    return true;
  }

  static Future<bool> _convertLinux(String src, String dest) async {
    for (final cmd in const [
      ['heif-convert', '-q', '92'],
      ['magick'],
      ['convert'],
    ]) {
      if (!await _hasBinary(cmd.first)) continue;
      final res = await Process.run(cmd.first, [...cmd.skip(1), src, dest]);
      if (res.exitCode == 0 && await File(dest).exists() && await File(dest).length() > 0) return true;
    }
    Logger.warn('No HEIF decoder on PATH (install libheif-tools or imagemagick)');
    return false;
  }

  static Future<bool> _convertMacOS(String src, String dest) async {
    if (await _hasBinary('sips')) {
      final res = await Process.run('sips', ['-s', 'format', 'jpeg', src, '--out', dest]);
      if (res.exitCode == 0 && await File(dest).exists() && await File(dest).length() > 0) return true;
    }
    if (await _hasBinary('heif-convert')) {
      final res = await Process.run('heif-convert', ['-q', '92', src, dest]);
      if (res.exitCode == 0 && await File(dest).exists() && await File(dest).length() > 0) return true;
    }
    return false;
  }

  static final Map<String, bool> _binaryCache = {};
  static Future<bool> _hasBinary(String name) async {
    if (_binaryCache.containsKey(name)) return _binaryCache[name]!;
    try {
      final r = await Process.run('sh', ['-c', 'command -v $name']);
      final ok = r.exitCode == 0 && (r.stdout as String).trim().isNotEmpty;
      _binaryCache[name] = ok;
      return ok;
    } catch (_) {
      _binaryCache[name] = false;
      return false;
    }
  }

  static String _swapExt(String path, String newExt) {
    return p.join(p.dirname(path), '${p.basenameWithoutExtension(path)}.$newExt');
  }
}
