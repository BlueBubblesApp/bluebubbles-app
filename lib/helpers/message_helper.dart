import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:bluebubble_messages/repository/models/attachment.dart';

class MessageHelper {
  static Future<List<Message>> bulkAddMessages(
      Chat chat, List<dynamic> messages) async {
    List<Message> _messages = <Message>[];
    messages.forEach((item) {
      Message message = Message.fromMap(item);
      _messages.add(message);
      chat.addMessage(message).then((value) {
        // Create the attachments
        List<dynamic> attachments = item['attachments'];

        attachments.forEach((attachmentItem) {
          Attachment file = Attachment.fromMap(attachmentItem);
          file.save(message);
        });
      });
    });
    return _messages;
  }
}
