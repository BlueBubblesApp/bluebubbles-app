import 'dart:async';

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/backend/interfaces/custom_group_interface.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:get/get.dart';

class CustomGroupsController extends GetxController {
  final RxList<CustomGroup> groups = <CustomGroup>[].obs;
  final RxBool loading = true.obs;

  StreamSubscription? _eventSub;

  @override
  void onInit() {
    super.onInit();
    loadGroups();
    _eventSub = EventDispatcherSvc.stream.listen((event) {
      if (event.type == 'custom-groups-updated') loadGroups();
    });
  }

  @override
  void onClose() {
    _eventSub?.cancel();
    super.onClose();
  }

  Future<void> loadGroups() async {
    loading.value = true;
    groups.value = await CustomGroupInterface.getAll();
    loading.value = false;
  }

  Future<void> createGroup(String name, List<String> chatGuids) async {
    await CustomGroupInterface.create(name: name, chatGuids: chatGuids);
  }

  Future<void> renameGroup(CustomGroup group, String name) async {
    await CustomGroupInterface.rename(id: group.id!, name: name);
  }

  Future<void> updateGroupChats(CustomGroup group, List<String> chatGuids) async {
    await CustomGroupInterface.updateChats(id: group.id!, chatGuids: chatGuids);
  }

  Future<void> setShowUnreadBadge(CustomGroup group, bool value) async {
    await CustomGroupInterface.setShowUnreadBadge(id: group.id!, value: value);
  }

  Future<void> deleteGroup(CustomGroup group) async {
    await CustomGroupInterface.delete(id: group.id!);
  }

  Future<void> reorderGroups(List<CustomGroup> newOrder) async {
    groups.value = newOrder;
    await CustomGroupInterface.reorder(ids: newOrder.map((g) => g.id!).toList());
  }
}
