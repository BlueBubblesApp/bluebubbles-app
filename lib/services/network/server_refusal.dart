import 'dart:convert';

import 'package:dio/dio.dart';

/// What the server said when it refused a request, read from its JSON envelope
/// (`{error: {message, data}, data, message}`).
///
/// [message] is its sentence for the user, [reason] its stable reason word, and [purchaseUrl], for a `402` (the
/// server lacks the subscription tier), the page to get one. All null when the server didn't answer with an envelope.
class ServerRefusal {
  final String? message;
  final String? reason;
  final String? purchaseUrl;
  final int? statusCode;

  const ServerRefusal({this.message, this.reason, this.purchaseUrl, this.statusCode});

  /// Reads [error]: a non-2xx [Response] (how `ApiInterceptor` surfaces one), a [DioException] carrying one, or a
  /// response body on its own. A body may still be bytes, as it is for routes that download images.
  factory ServerRefusal.from(Object? error) {
    final response = switch (error) {
      Response() => error,
      DioException() => error.response,
      _ => null,
    };
    final body = _decode(response == null ? error : response.data);
    final err = body['error'] is Map ? body['error'] as Map : const {};
    final data = body['data'] is Map
        ? body['data'] as Map
        : err['data'] is Map
        ? err['data'] as Map
        : const {};
    final message = (err['message'] ?? body['message'])?.toString();
    return ServerRefusal(
      message: message == null || message.isEmpty ? null : message,
      reason: data['reason']?.toString(),
      purchaseUrl: data['purchase_url']?.toString(),
      statusCode: response?.statusCode,
    );
  }

  static Map _decode(Object? body) {
    if (body is Map) return body;
    if (body is! List<int>) return const {};
    try {
      final decoded = jsonDecode(utf8.decode(body));
      return decoded is Map ? decoded : const {};
    } on FormatException {
      // Not the server's envelope; the status code alone still says what happened
      return const {};
    }
  }
}
