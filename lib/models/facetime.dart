/// A FaceTime call the server's Mac is on, from `/api/v2/facetime/*`'s `call` object.
class FaceTimeCall {
  final String callUuid;
  final String? status;
  final bool isVideo;
  final String? address;
  final String? groupUuid;

  const FaceTimeCall({required this.callUuid, this.status, this.isVideo = true, this.address, this.groupUuid});

  factory FaceTimeCall.fromMap(Map<String, dynamic> map) => FaceTimeCall(
    callUuid: map['call_uuid'] as String,
    status: map['status'] as String?,
    isVideo: map['is_video'] as bool? ?? true,
    address: map['address'] as String?,
    groupUuid: map['group_uuid'] as String?,
  );
}

/// What `POST facetime/call` answers with: the call now ringing, and the link to join it.
class PlacedFaceTimeCall {
  final String link;
  final FaceTimeCall call;

  const PlacedFaceTimeCall({required this.link, required this.call});
}

/// A refusal from the server's FaceTime routes, carrying its sentence for the user.
///
/// [call] is set when the call was placed but no link could be minted for it: the call is
/// ringing, so the caller should offer to hang it up (`FaceTimeApi.leave`).
class FaceTimeException implements Exception {
  final String message;
  final int? statusCode;
  final FaceTimeCall? call;

  const FaceTimeException(this.message, {this.statusCode, this.call});

  @override
  String toString() => message;
}
