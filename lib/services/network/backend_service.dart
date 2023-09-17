import 'package:bluebubbles/services/rustpush/rustpush_service.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/models/global/platform_file.dart';

BackendService backend = Get.isRegistered<BackendService>() ? Get.find<BackendService>() : Get.put(RustPushBackend());

abstract class BackendService {
  Future<Map<String, dynamic>> createChat(List<String> addresses, String? message, String service, {CancelToken? cancelToken});
  Future<Map<String, dynamic>> sendMessage(String chatGuid, String tempGuid, String message, {String? method, String? effectId, String? subject, String? selectedMessageGuid, int? partIndex, CancelToken? cancelToken});
  Future<bool> renameChat(String chatGuid, String newName);
  Future<bool> chatParticipant(String method, String chatGuid, String newName);
  Future<bool> leaveChat(String chatGuid);
  Future<Map<String, dynamic>> sendTapback(String chatGuid, String selectedText, String selectedGuid, String reaction, int? repPart);
  Future<bool> markRead(String chatGuid);
  HttpService? getRemoteService();
  bool canLeaveChat();
  bool canEditUnsend();
  Future<Map<String, dynamic>?> unsend(String msgGuid, int part);
  Future<Map<String, dynamic>?> edit(String msgGuid, String text, int part);
  Future<Map<String, dynamic>?> downloadAttachment(String guid, {void Function(int, int)? onReceiveProgress, bool original = false, CancelToken? cancelToken});
  // returns the new message that was sent
  Future<Map<String, dynamic>?> sendAttachment(String chatGuid, String tempGuid, PlatformFile file, {void Function(int, int)? onSendProgress, String? method, String? effectId, String? subject, String? selectedMessageGuid, int? partIndex, bool? isAudioMessage, CancelToken? cancelToken});
  bool canCancelUploads();
  Future<bool> canUploadGroupPhotos();
  Future<bool> setChatIcon(String guid, String path, {void Function(int, int)? onSendProgress, CancelToken? cancelToken});
  Future<bool> deleteChatIcon(String guid, {CancelToken? cancelToken});
  bool supportsFocusStates();
  Future<bool> downloadLivePhoto(String guid, String target, {void Function(int, int)? onReceiveProgress, CancelToken? cancelToken});
  bool canSchedule();
  bool supportsFindMy();
}