import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/env.dart';
import 'package:bluebubbles/services/backend/actions/custom_group_actions.dart';
import 'package:bluebubbles/services/isolates/global_isolate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:get_it/get_it.dart';

class CustomGroupInterface {
  static Future<List<CustomGroup>> getAll() async {
    final ids = isIsolate
        ? await CustomGroupActions.getAllIds({})
        : await GetIt.I<GlobalIsolate>().send<List<int>>(IsolateRequestType.getAllCustomGroups, input: {});
    return ids.map((id) => Database.customGroups.get(id)).whereType<CustomGroup>().toList();
  }

  static Future<CustomGroup> create({required String name, required List<String> chatGuids}) async {
    final data = {'name': name, 'chatGuids': chatGuids};
    final id = isIsolate
        ? await CustomGroupActions.create(data)
        : await GetIt.I<GlobalIsolate>().send<int>(IsolateRequestType.createCustomGroup, input: data);
    EventDispatcherSvc.emit('custom-groups-updated', null);
    return Database.customGroups.get(id)!;
  }

  static Future<CustomGroup> rename({required int id, required String name}) async {
    final data = {'id': id, 'name': name};
    final resultId = isIsolate
        ? await CustomGroupActions.rename(data)
        : await GetIt.I<GlobalIsolate>().send<int>(IsolateRequestType.renameCustomGroup, input: data);
    EventDispatcherSvc.emit('custom-groups-updated', null);
    return Database.customGroups.get(resultId)!;
  }

  static Future<CustomGroup> updateChats({required int id, required List<String> chatGuids}) async {
    final data = {'id': id, 'chatGuids': chatGuids};
    final resultId = isIsolate
        ? await CustomGroupActions.updateChats(data)
        : await GetIt.I<GlobalIsolate>().send<int>(IsolateRequestType.updateCustomGroupChats, input: data);
    EventDispatcherSvc.emit('custom-groups-updated', null);
    return Database.customGroups.get(resultId)!;
  }

  static Future<CustomGroup> setShowUnreadBadge({required int id, required bool value}) async {
    final data = {'id': id, 'value': value};
    final resultId = isIsolate
        ? await CustomGroupActions.setShowUnreadBadge(data)
        : await GetIt.I<GlobalIsolate>().send<int>(IsolateRequestType.setCustomGroupShowUnreadBadge, input: data);
    EventDispatcherSvc.emit('custom-groups-updated', null);
    return Database.customGroups.get(resultId)!;
  }

  static Future<void> reorder({required List<int> ids}) async {
    final data = {'ids': ids};
    if (isIsolate) {
      await CustomGroupActions.reorder(data);
    } else {
      await GetIt.I<GlobalIsolate>().send<void>(IsolateRequestType.reorderCustomGroups, input: data);
    }
    EventDispatcherSvc.emit('custom-groups-updated', null);
  }

  static Future<void> delete({required int id}) async {
    final data = {'id': id};
    if (isIsolate) {
      await CustomGroupActions.delete(data);
    } else {
      await GetIt.I<GlobalIsolate>().send<void>(IsolateRequestType.deleteCustomGroup, input: data);
    }
    EventDispatcherSvc.emit('custom-groups-updated', null);
  }
}
