import 'package:bluebubbles/models/models.dart';

/// Get all audio transcripts from a list of attributed bodies
/// 
/// [attrBodies] is a list of attributed body objects
/// 
/// Returns a map of audio transcripts with the message part number as the key
Map<int, String> getAudioTranscriptsFromAttributedBody(List<AttributedBody> attrBodies) {
  Map<int, String> transcripts = {};
  for (AttributedBody body in attrBodies) {
    for (Run run in body.runs) {
      if (run.attributes?.audioTranscript != null) {
        int partNum = run.attributes!.messagePart ?? 0;
        transcripts[partNum] = run.attributes!.audioTranscript!;
      }
    }
  }

  return transcripts;
}