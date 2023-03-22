/*
import 'package:bluebubbles/utils/parsers/event_payload/api_payload.dart';
import 'package:bluebubbles/services/services.dart';

class ApiPayloadParser {

  ApiPayload payload;

  late Map<String, Function> enrichmentRefs = {};

  ApiPayloadParser(this.payload) {
    enrichmentRefs = {
      'messages': enrichMessages,
      'chats': enrichChats,
      'attachments': enrichAttachments,
      'participants': enrichHandles,
    };
  }

  Future<dynamic> parse() async {
    if (payload.isLegacy) {
      return await parseLegacyPayload();
    } else {
      return await parsePayload();
    }
  }

  Future<dynamic> parseLegacyPayload() async {
    // If the payload is legacy, we just should return the payload itself.
    // This is because the payload is already in a readable format
    return payload.payload;
  }

  Future<dynamic> parsePayload() async {
    // If the data is null or a string, return the raw payload
    if (payload.data == null || payload.dataIsString) return payload.payload;

    if ([PayloadType.NEW_MESAGE, PayloadType.UPDATED_MESSAGE, PayloadType.MESSAGE].contains(payload.type)) {
      return await parseMessage(payload);
    } else if (payload.type == PayloadType.CHAT) {
      return await parseChat(payload);
    } else if (payload.type == PayloadType.ATTACHMENT) {
      return await parseAttachment(payload);
    } else if (payload.type == PayloadType.HANDLE) {
      return await parseHandle(payload);
    } else {
      return null;
    }
  }

  Future<dynamic> parseMessage(ApiPayload payload) async {
    List<dynamic> data = payload.dataIsList ? payload.data : [payload.data];
    bool needsEnrichment = data.isNotEmpty && data.every((i) => i is String);

    if (needsEnrichment) {
      payload.data = await enrichEntity('messages', payload);
    }

    return payload;
  }

  Future<List<dynamic>> enrichEntity(String entity, ApiPayload payload) async {
    List<dynamic> output = payload.dataIsList ? payload.data : [payload.data];
    bool needsEnrichment = output.isNotEmpty && output.every((i) => i is String);
    
    if (!enrichmentRefs.containsKey(entity)) {
      throw Exception('Invalid entity type: $entity');
    }

    if (needsEnrichment) {
      output = await enrichmentRefs[entity]!(output as List<String>);
    }

    return payload.dataIsList ? output : (output.isNotEmpty ? output.first : null);
  }

  Future<List<dynamic>> enrichMessages(List<String> guids) async {
    // Fetch the corresponding messages from the API.
    // For messages, we need the latest n' greatest.
    List<dynamic> messages = await MessagesService.getMessages(
        limit: guids.length,
        withChats: true,
        withHandles: true,
        withAttachments: true,
        withChatParticipants: true,
        where: [
          {
            'statement': 'message.guid IN (:...guids)',
            'args': {'guids': guids}
          }
        ]
    );

    // Create a map of the messages where the GUID is the key
    Map<String, dynamic> messagesMap = {};
    for (var message in messages) {
      messagesMap[message['guid']] = message;
    }

    // Return a list of message dictionaries, in place of the GUIDs
    return guids.where(
      (guid) => messagesMap.containsKey(guid)).map((guid) => messagesMap[guid]).toList();
  }

  dynamic parseAttachment(dynamic payload) {
    bool needsEnrichment = payload.dataIsList && payload.data.length > 0 && payload.data[0] is String;

  }

  Future<List<dynamic>> enrichAttachments(List<String> guids) async {
    // TODO: Implement attachment query endpoint
    return [];
  }

  dynamic parseChat(dynamic payload) {
    bool needsEnrichment = payload.dataIsList && payload.data.length > 0 && payload.data[0] is String;

  }

  Future<List<dynamic>> enrichChats(List<String> guids) async {
    // TODO: Implement chat query endpoint
    return [];
  }

  dynamic parseHandle(dynamic payload) {
    bool needsEnrichment = payload.dataIsList && payload.data.length > 0 && payload.data[0] is String;

  }

  Future<List<dynamic>> enrichHandles(List<String> addresses) async {
    // TODO: Implement handle query endpoint
    return [];
  }
}*/
