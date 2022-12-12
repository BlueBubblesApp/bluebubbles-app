class ScheduledMessage {
  int? id;
  String? chatGuid;
  String? message;
  int? epochTime;
  bool? completed;

  ScheduledMessage({this.id, this.chatGuid, this.message, this.epochTime, this.completed});

  factory ScheduledMessage.fromMap(Map<String, dynamic> json) {
    return ScheduledMessage(
        id: json.containsKey("ROWID") ? json["ROWID"] : null,
        chatGuid: json["chatGuid"],
        message: json["message"],
        epochTime: json["epochTime"],
        completed: json["completed"] == 0 ? false : true);
  }

  ScheduledMessage save() {
    return this;
  }

  static List<ScheduledMessage> find() {
    return [];
  }

  static void flush() {
    return;
  }

  Map<String, dynamic> toMap() =>
      {"ROWID": id, "chatGuid": chatGuid, "message": message, "epochTime": epochTime, "completed": completed! ? 1 : 0};
}
