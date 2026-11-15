import 'package:bluebubbles/database/models.dart';

/// Encapsulates all data required to perform a single send operation.
///
/// Passed from the text field / recorder through [ConversationViewController]
/// to [SendAnimation], replacing the previous ad-hoc Tuple6 + isAudioMessage pair.
class SendData {
  const SendData({
    required this.attachments,
    required this.text,
    this.runs = const [],
    required this.subject,
    this.replyGuid,
    this.replyPart,
    this.effectId,
    this.isAudioMessage = false,
  });

  final List<PlatformFile> attachments;
  final String text;
  final List<Run> runs;
  final String subject;
  final String? replyGuid;
  final int? replyPart;
  final String? effectId;

  /// Whether the attached file is a voice/audio recording.
  final bool isAudioMessage;
}
