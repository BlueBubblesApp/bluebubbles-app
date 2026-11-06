import 'package:bluebubbles/env.dart';
import 'package:bluebubbles/models/models.dart' show ServerDetails, ServerUpdateInfo;
import 'package:bluebubbles/services/backend/actions/server_actions.dart';
import 'package:get_it/get_it.dart';
import 'package:bluebubbles/services/isolates/global_isolate.dart';

class ServerInterface {
  static Future<ServerUpdateInfo> checkForServerUpdate() async {
    late Map<String, dynamic> response;
    if (isIsolate) {
      response = await ServerActions.checkForServerUpdate();
    } else {
      response = await GetIt.I<GlobalIsolate>().send<Map<String, dynamic>>(IsolateRequestType.checkForServerUpdate);
    }

    final metadata = response['metadata'] as Map<String, dynamic>;
    return ServerUpdateInfo(
      available: response['available'] as bool,
      version: metadata['version'] as String?,
      releaseDate: metadata['release_date'] as String?,
      releaseName: metadata['release_name'] as String?,
    );
  }

  static Future<ServerDetails> getServerDetails() async {
    late Map<String, dynamic> response;

    if (isIsolate) {
      response = await ServerActions.getServerDetails();
    } else {
      response = await GetIt.I<GlobalIsolate>().send<Map<String, dynamic>>(IsolateRequestType.getServerDetails);
    }

    if (response.isEmpty) throw Exception("Server info request failed");
    return ServerDetails.fromMap(response);
  }
}
