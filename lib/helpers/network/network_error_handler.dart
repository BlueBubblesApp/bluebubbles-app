import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:dio/dio.dart';

Message handleSendError(dynamic error, Message m) {
  if (error is Response) {
    m.guid = m.guid!.replaceAll("temp", "error-${error.data['error']['message'] ?? error.data.toString()}");
    m.error = error.statusCode ?? MessageError.BAD_REQUEST.code;
  } else if (error is DioError) {
    String _error;
    if (error.type == DioErrorType.connectionTimeout) {
      _error = "Connect timeout occured! Check your connection.";
    } else if (error.type == DioErrorType.sendTimeout) {
      _error = "Send timeout occured!";
    } else if (error.type == DioErrorType.receiveTimeout) {
      _error = "Receive data timeout occured! Check server logs for more info.";
    } else {
      _error = error.error.toString();
    }
    m.guid = m.guid!.replaceAll("temp", "error-$_error");
    m.error = error.response?.statusCode ?? MessageError.BAD_REQUEST.code;
  } else {
    m.guid = m.guid!.replaceAll("temp", "error-Connection timeout, please check your internet connection and try again");
    m.error = MessageError.BAD_REQUEST.code;
  }

  return m;
}