import 'dart:async';

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/backend/interfaces/custom_group_interface.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

// ignore: non_constant_identifier_names
CustomGroupsService get CustomGroupsSvc => GetIt.I<CustomGroupsService>();

/// Lightweight read-only reactive cache of all custom groups, used by the
/// Chat Filters sheet so it doesn't hit the DB every time it opens.
class CustomGroupsService {
  final RxList<CustomGroup> groups = <CustomGroup>[].obs;

  StreamSubscription? _eventSub;

  Future<void> init() async {
    await refresh();
    _eventSub = EventDispatcherSvc.stream.listen((event) {
      if (event.type == 'custom-groups-updated') refresh();
    });
  }

  Future<void> refresh() async {
    groups.value = await CustomGroupInterface.getAll();
    // Drop any filter selection pointing at a group that no longer exists
    // (e.g. just got deleted). ChatsSvc is guaranteed to be registered by the
    // time this runs — it initializes earlier in the startup sequence.
    if (GetIt.I.isRegistered<ChatsService>()) {
      ChatsSvc.pruneStaleCustomGroupIds();
    }
  }

  void dispose() {
    _eventSub?.cancel();
  }
}
