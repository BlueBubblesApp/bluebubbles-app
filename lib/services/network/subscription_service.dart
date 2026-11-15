import 'dart:async';

import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:get_it/get_it.dart';

// ignore: non_constant_identifier_names
SubscriptionService get SubscriptionSvc => GetIt.I<SubscriptionService>();

/// Whether the server holds the Pro subscription its paid features need (games, stickers, Genmoji), from
/// `GET /api/v2/server/subscription`. Checked at startup, on resume, whenever the server changes, and when the socket
/// reconnects after a check that couldn't reach it.
///
/// That route needs the `server:admin` scope, so a narrower token can't ask: then any route that answers `402`
/// says it instead ([HttpService] reports it here through [refused]).
class SubscriptionService {
  /// Null until known: not checked yet, not a v2 server's question, or the check couldn't be made. Gate on [locked]
  /// to lock a feature once the server has said no (or can't be reached to ask), and on [hasPro] to offer one only once
  /// it has said yes.
  final RxnBool _pro = RxnBool();

  /// The last check couldn't reach the server (no connection, a timeout, a 5xx)
  final RxBool _unreachable = false.obs;

  /// Where the server says a subscription can be bought.
  final RxnString purchaseUrl = RxnString();

  /// Developer Tools' "Disable Subscription Features": act as if the server had no subscription. Not saved, so it
  /// can't be left on.
  final RxBool debugDisabled = false.obs;

  bool get hasPro => !debugDisabled.value && _pro.value == true;

  /// No answer yet because the server can't be reached: paid features say the server is offline rather than ask for
  /// a subscription it may well have.
  bool get offline => !debugDisabled.value && _pro.value == null && _unreachable.value;

  bool get locked => debugDisabled.value || _pro.value == false || offline;

  Worker? _serverWorker;
  Worker? _socketWorker;

  void init() {
    _serverWorker = ever(SettingsSvc.serverDetailsChanges, (_) => unawaited(refresh()));
    _socketWorker = ever(SocketSvc.state, (SocketState state) {
      if (state == SocketState.connected && _unreachable.value) unawaited(refresh());
    });
    unawaited(refresh());
  }

  void dispose() {
    _serverWorker?.dispose();
    _socketWorker?.dispose();
  }

  Future<void> refresh() async {
    if (!SettingsSvc.serverDetails.isV2Server) {
      _pro.value = null;
      _unreachable.value = false;
      return;
    }
    final Response response;
    try {
      response = await HttpSvc.server.subscription();
    } catch (e) {
      // A 4xx is the server's answer. Anything else (a timeout, no connection, a 5xx) says nothing about the
      // subscription, so the last answer stands rather than locking features every time a resume beats the network
      final status = switch (e) {
        Response() => e.statusCode,
        DioException() => e.response?.statusCode,
        _ => null,
      };
      _unreachable.value = status == null || status >= 500;
      if (status != null && status >= 400 && status < 500) {
        // A token without `server:admin` can't ask: that's no answer, and a 402 from a paid route will give one
        if (status == 401 || status == 403) return;
        Logger.warn('The server refused the subscription check ($status)', tag: 'Subscription');
        _pro.value = false;
      } else {
        Logger.warn('Could not check the server subscription', error: e, tag: 'Subscription');
      }
      return;
    }
    _unreachable.value = false;
    try {
      final data = response.data['data'] as Map<String, dynamic>;
      final tiers = (data['available_tiers'] as List? ?? const []).whereType<Map>().toList();
      final pro = tiers.firstWhereOrNull((t) => t['id'] == 'pro');
      final held = tiers.firstWhereOrNull((t) => t['id'] == data['tier']);
      purchaseUrl.value = pro?['purchase_url'] as String? ?? purchaseUrl.value;
      // Pro or above, compared by rank. A tier the server doesn't list is newer than its build, and the server still
      // ranks it from the license, so only a listed tier below Pro is refused.
      _pro.value = data['tier'] != null &&
          (held == null || pro == null || (held['rank'] as int) >= (pro['rank'] as int));
    } catch (e) {
      // A reply this build can't read isn't an answer either
      Logger.warn('Could not read the server subscription', error: e, tag: 'Subscription');
    }
  }

  /// A paid route answered `402`: the server has no subscription after all. [body] is the refusal's JSON, which
  /// carries where to buy one.
  void refused(Object? body) {
    _pro.value = false;
    _unreachable.value = false;
    if (body is! Map) return;
    final error = body['error'] is Map ? body['error'] as Map : const {};
    final data = body['data'] is Map
        ? body['data'] as Map
        : error['data'] is Map
        ? error['data'] as Map
        : const {};
    purchaseUrl.value = data['purchase_url'] as String? ?? purchaseUrl.value;
  }
}
