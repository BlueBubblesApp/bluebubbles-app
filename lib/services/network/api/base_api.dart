import 'package:dio/dio.dart';

/// Minimal interface exposed to API sub-services so they can make
/// requests without creating a circular import with [HttpService].
abstract interface class BaseApi {
  Dio get dio;
  String get origin;
  String get apiRoot;

  /// Root of the v2 surface. Only call it when `ServerDetails.isV2Server` is true.
  String get apiRootV2;
  Map<String, String> get headers;
  Map<String, dynamic> buildQueryParams([Map<String, dynamic> params = const {}]);
  Future<Response> runApiGuarded(Future<Response> Function() func, {bool checkOrigin = true});
  Future<Response> returnSuccessOrError(Response r);
}
