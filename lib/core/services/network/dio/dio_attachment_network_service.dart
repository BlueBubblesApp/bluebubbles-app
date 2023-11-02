import 'package:bluebubbles/core/abstractions/network/attachment_network_service.dart';
import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';
import 'package:bluebubbles/core/services/network/dio/dio_network_service.dart';


class DioAttachmentNetworkService implements AttachmentNetworkService {

  @override
  bool isAvailable = true;

  DioNetworkService network;

  DioAttachmentNetworkService(this.network);
  
  @override
  Future count({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
      "/attachment/count",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future download(String guid, {bool original = false, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
        "/attachment/$guid/download",
        params: {"original": original},
        options: network.defaultDownloadOpts,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future downloadBlurhash(String guid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
      "/attachment/$guid/blurhash",
      options: network.defaultDownloadOpts,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future downloadLivePhoto(String guid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
      "/attachment/$guid/live",
      options: network.defaultDownloadOpts,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future get(String guid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
        "/attachment/$guid",
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress
    );
  }
  
}