class ScheduledMessage {
  int? id;
  String? chatGuid;
  String? message;
  int? epochTime;
  bool? completed;

  ScheduledMessage({this.id, this.chatGuid, this.message, this.epochTime, this.completed});

  factory ScheduledMessage.fromMap(Map<String, dynamic> json) => throw Exception("Unsupported Platform");

  ScheduledMessage save() => throw Exception("Unsupported Platform");

  static List<ScheduledMessage> find() => throw Exception("Unsupported Platform");

  static void flush() => throw Exception("Unsupported Platform");

  Map<String, dynamic> toMap() => throw Exception("Unsupported Platform");
}
