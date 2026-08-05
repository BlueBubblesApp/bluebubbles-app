import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:dio/dio.dart';

/// Classifies a send failure, sets [Message.error] and [Message.errorMessage],
/// and returns the updated message.
///
/// The GUID is **never** mutated here — it stays as the original `temp-{uuid}`
/// so it remains a stable reference throughout the retry lifecycle.
Message handleSendError(dynamic error, Message m) {
  ClientMessageError clientError;
  String errorMessageText;

  if (error is Response) {
    final statusCode = error.statusCode ?? 0;

    switch (statusCode) {
      case 502:
        clientError = ClientMessageError.badGateway;
        errorMessageText = "Server returned 502: Bad Gateway. Check server logs.";
        break;
      case 504:
        clientError = ClientMessageError.gatewayTimeout;
        errorMessageText = "Server returned 504: Gateway Timeout.";
        break;
      case 404:
        clientError = ClientMessageError.notFound;
        errorMessageText = "Endpoint not found (404). Your server URL may be outdated.";
        break;
      default:
        clientError = ClientMessageError.clientError;
        errorMessageText = _normalizeErrorData(error.data) ?? "Server error ($statusCode).";
    }
  } else if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        clientError = ClientMessageError.gatewayTimeout;
        errorMessageText = "Connection timed out. Check your connection.";
        break;
      case DioExceptionType.sendTimeout:
        clientError = ClientMessageError.gatewayTimeout;
        errorMessageText = "Send timed out. Check your connection.";
        break;
      case DioExceptionType.receiveTimeout:
        clientError = ClientMessageError.gatewayTimeout;
        errorMessageText = "Response timed out. Check server logs for more info.";
        break;
      case DioExceptionType.connectionError:
        clientError = ClientMessageError.connectionRefused;
        errorMessageText = "Connection refused. Is the server running?";
        break;
      default:
        clientError = ClientMessageError.clientError;
        errorMessageText = error.message ?? error.error?.toString() ?? "An unknown client error occurred.";
    }
  } else {
    clientError = ClientMessageError.clientError;
    errorMessageText = error.toString();
  }

  m.error = clientError.code;
  m.errorMessage = errorMessageText;
  return m;
}

/// Normalizes a server error response body shaped like `{status, message, error: {type, message}}`
/// into a single readable string. Falls back to whatever subset of keys is present:
/// `[status] error.type: error.message` -> `[status] message` -> `null` (caller supplies fallback).
String? _normalizeErrorData(dynamic data) {
  if (data is! Map) return null;

  final status = data['status'];
  final nestedError = data['error'];
  if (nestedError is Map) {
    final type = nestedError['type'];
    final message = nestedError['message'];
    if (type != null && message != null) {
      return status != null ? "[$status] $type: $message" : "$type: $message";
    }
  }

  final message = data['message'];
  if (message != null) {
    return status != null ? "[$status] $message" : message.toString();
  }

  return null;
}
