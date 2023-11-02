import 'package:bluebubbles/core/abstractions/network/network_service.dart';
import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';
import 'package:bluebubbles/models/global/platform_file.dart';


abstract class MessageNetworkService extends SubNetworkService {
  Future<dynamic> count({bool updated = false, bool onlyMe = false, DateTime? after, DateTime? before, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> query({List<String> withQuery = const [], List<dynamic> where = const [], String sort = "DESC", int? before, int? after, String? chatGuid, int offset = 0, int limit = 100, bool convertAttachments = true, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> get(String guid, {String withQuery = "", NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> getEmbeddedMedia(String guid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> sendText(String chatGuid, String tempGuid, String message, {String? method, String? effectId, String? subject, String? selectedMessageGuid, int? partIndex, bool? ddScan, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> sendAttachment(String chatGuid, String tempGuid, PlatformFile file, {String? method, String? effectId, String? subject, String? selectedMessageGuid, int? partIndex, bool? isAudioMessage, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> sendMultipart(String chatGuid, String tempGuid, List<Map<String, dynamic>> parts, {String? effectId, String? subject, String? selectedMessageGuid, int? partIndex, bool? ddScan, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> sendTapback(String chatGuid, String selectedMessageText, String selectedMessageGuid, String reaction, {int? partIndex, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> unsend(String selectedMessageGuid, {int? partIndex, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> edit(String selectedMessageGuid, String edit, String backwardsCompatText, {int? partIndex, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> notify(String selectedMessageGuid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
}