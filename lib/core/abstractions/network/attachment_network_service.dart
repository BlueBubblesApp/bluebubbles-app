import 'package:bluebubbles/core/abstractions/network/network_service.dart';
import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';


abstract class AttachmentNetworkService implements SubNetworkService {
  Future<dynamic> get(String guid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> count({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> download(String guid, {bool original = false, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> downloadLivePhoto(String guid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> downloadBlurhash(String guid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
}