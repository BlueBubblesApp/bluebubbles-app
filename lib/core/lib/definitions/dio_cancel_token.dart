import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';
import 'package:dio/dio.dart';

class DioCancelToken implements NetworkCancelToken {
  CancelToken token = CancelToken();

  static fromToken(CancelToken token) {
    DioCancelToken dioToken = DioCancelToken();
    dioToken.token = token;
    return dioToken;
  }

  @override
  void cancel([Object? reason]) {
    token.cancel(reason);
  }
}