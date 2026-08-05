import 'package:bluebubbles/env.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/backend/actions/storage_actions.dart';
import 'package:bluebubbles/services/backend/filesystem/filesystem_service.dart';
import 'package:bluebubbles/services/backend_ui_interop/event_dispatcher.dart';
import 'package:bluebubbles/services/isolates/global_isolate.dart';
import 'package:bluebubbles/services/network/downloads_service.dart';
import 'package:bluebubbles/services/ui/attachments_service.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

class StorageInterface {
  static Future<StorageAnalysisResult> analyze({
    String? chatGuid,
    required StorageAgeFilter ageFilter,
    required String runId,
  }) async {
    final data = {
      'chatGuid': chatGuid,
      'ageFilter': ageFilter.name,
      'runId': runId,
      'attachmentsPath': FilesystemSvc.attachmentsPath,
      'urlPreviewsPath': FilesystemSvc.urlPreviewsPath,
    };

    final Map<String, dynamic> result = isIsolate
        ? await StorageActions.analyze(data)
        : await GetIt.I<GlobalIsolate>().send<Map<String, dynamic>>(
            IsolateRequestType.analyzeStorage,
            input: data,
            customTimeout: const Duration(minutes: 10),
          );

    return StorageAnalysisResult.fromMap(result);
  }

  static Future<StorageDeleteResult> deleteAttachments({
    String? chatGuid,
    required StorageAgeFilter ageFilter,
    required Set<StorageSegmentType> segments,
  }) async {
    final data = {
      'chatGuid': chatGuid,
      'ageFilter': ageFilter.name,
      'segments': segments.map((s) => s.name).toList(),
      'attachmentsPath': FilesystemSvc.attachmentsPath,
      'urlPreviewsPath': FilesystemSvc.urlPreviewsPath,
    };

    final Map<String, dynamic> result = isIsolate
        ? await StorageActions.deleteAttachments(data)
        : await GetIt.I<GlobalIsolate>().send<Map<String, dynamic>>(
            IsolateRequestType.deleteStorageAttachments,
            input: data,
            customTimeout: const Duration(minutes: 10),
          );

    // Main-thread cleanup — these touch GetX/Flutter singletons unavailable
    // inside the isolate, mirroring the tail of redownloadAttachment.
    final guids = (result['guids'] as List).cast<String>();
    AttachmentsSvc.clearVideoThumbnailCache();
    for (final g in guids) {
      AttachmentDownloader.clearControllerForGuid(g);
    }
    imageCache.clear();
    imageCache.clearLiveImages();

    // "refresh-messagebloc" is per-chat and this purge can span chats, so a
    // dedicated global event drives open conversation views to re-check
    // Attachment.existsOnDisk instead.
    EventDispatcherSvc.emit('storage-attachments-purged', {'guids': guids});

    return StorageDeleteResult.fromMap(result);
  }
}
