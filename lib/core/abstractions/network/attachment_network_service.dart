import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';


abstract class AttachmentNetworkService {
  Future<dynamic> get(String guid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> count({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> download(String guid, {bool original = false, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> downloadLivePhoto(String guid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> downloadBlurhash(String guid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
}