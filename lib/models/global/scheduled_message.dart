class ScheduledMessage {
  ScheduledMessage({
    required this.id,
    required this.type,
    required this.payload,
    required this.scheduledFor,
    required this.schedule,
    required this.status,
    this.error,
    this.sentAt,
    required this.created,
  });

  int id;
  String type;
  Payload payload;
  DateTime scheduledFor;
  Schedule schedule;
  String status;
  String? error;
  DateTime? sentAt;
  DateTime created;

  factory ScheduledMessage.fromJson(Map<String, dynamic> json) => ScheduledMessage(
    id: json["id"],
    type: json["type"],
    payload: Payload.fromJson(json["payload"]),
    scheduledFor: DateTime.parse(json["scheduledFor"]).toLocal(),
    schedule: Schedule.fromJson(json["schedule"]),
    status: json["status"],
    error: json["error"],
    sentAt: json["sentAt"] == null ? null : DateTime.tryParse(json["sentAt"])?.toLocal(),
    created: DateTime.parse(json["created"]).toLocal(),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "type": type,
    "payload": payload.toJson(),
    "scheduledFor": scheduledFor.toIso8601String(),
    "schedule": schedule.toJson(),
    "status": status,
    "error": error,
    "sentAt": sentAt?.toIso8601String(),
    "created": created.toIso8601String(),
  };
}

class Payload {
  Payload({
    required this.chatGuid,
    required this.message,
    required this.method,
  });

  String chatGuid;
  String message;
  String method;

  factory Payload.fromJson(Map<String, dynamic> json) => Payload(
    chatGuid: json["chatGuid"],
    message: json["message"],
    method: json["method"],
  );

  Map<String, dynamic> toJson() => {
    "chatGuid": chatGuid,
    "message": message,
    "method": method,
  };
}

class Schedule {
  Schedule({
    required this.type,
    this.interval,
    this.intervalType,
  });

  String type;
  int? interval;
  String? intervalType;

  factory Schedule.fromJson(Map<String, dynamic> json) => Schedule(
    type: json["type"],
    interval: json["interval"],
    intervalType: json["intervalType"],
  );

  Map<String, dynamic> toJson() => {
    "type": type,
    "interval": interval,
    "intervalType": intervalType,
  };
}
