import 'package:get/get.dart';

/// Return the future with either a value or error, depending on response from API
Future<dynamic> returnSuccessOrError(Response<dynamic> r) {
  if (r.statusCode == 200) {
    return Future.value(r.body);
  } else {
    return Future.error(r.body);
  }
}