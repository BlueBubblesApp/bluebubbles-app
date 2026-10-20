import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';

typedef RecoverableDeleteBatchNotice = void Function(String title, String message, SnackbarType type);

class RecoverableDeleteBatchSummary {
  const RecoverableDeleteBatchSummary({required this.total, required this.accepted, required this.failedChats});

  final int total;
  final int accepted;
  final List<Chat> failedChats;

  int get failed => failedChats.length;
}

Future<RecoverableDeleteBatchSummary> coordinateRecoverableDeleteBatch({
  required List<Chat> selectedChats,
  required Future<bool> Function(Chat chat) deleteChat,
  required Chat? Function(String guid) currentChat,
  required void Function(List<Chat> chats) replaceSelection,
  required RecoverableDeleteBatchNotice showNotice,
}) async {
  final snapshot = List<Chat>.of(selectedChats);
  if (snapshot.isEmpty) {
    return const RecoverableDeleteBatchSummary(total: 0, accepted: 0, failedChats: []);
  }
  final failed = <Chat>[];
  for (final chat in snapshot) {
    if (!await deleteChat(chat)) failed.add(chat);
  }

  final reboundFailures = failed.map((chat) => currentChat(chat.guid) ?? chat).toList(growable: false);
  replaceSelection(reboundFailures);
  final accepted = snapshot.length - reboundFailures.length;
  if (reboundFailures.isEmpty) {
    final plural = accepted != 1;
    showNotice(
      plural ? 'Deletion requests started' : 'Deletion request started',
      '$accepted deletion request${plural ? 's' : ''} started.',
      SnackbarType.success,
    );
  } else if (accepted == 0) {
    final plural = reboundFailures.length != 1;
    showNotice(
      plural ? 'Deletion requests not started' : 'Deletion request not started',
      plural
          ? '${reboundFailures.length} deletion requests could not be started. '
                '${reboundFailures.length} conversations remain selected.'
          : 'The deletion request could not be started. 1 conversation remains selected.',
      SnackbarType.error,
    );
  } else {
    final failedPlural = reboundFailures.length != 1;
    showNotice(
      'Deletion requests started',
      '$accepted of ${snapshot.length} deletion requests started. '
          '${reboundFailures.length} conversation${failedPlural ? 's' : ''} could not be requested and '
          '${failedPlural ? 'remain' : 'remains'} selected.',
      SnackbarType.error,
    );
  }
  return RecoverableDeleteBatchSummary(total: snapshot.length, accepted: accepted, failedChats: reboundFailures);
}
