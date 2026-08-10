import 'package:bluebubbles/helpers/network/metadata/models/metadata_fetch_result.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';

/// Decides whether a URL is safe for the app to fetch on the user's behalf.
///
/// Link previews are fetched automatically for links other people send, which
/// makes the fetch an attacker-controlled request originating from inside the
/// user's network. Without this guard, texting someone
/// `http://192.168.1.1/reboot` makes their phone issue that request against
/// their own router.
///
/// Detection is best-effort by design: literal addresses are always caught,
/// and hostnames are resolved on native platforms so that a domain pointing at
/// a private address is caught too.
abstract final class UrlSafetyGuard {
  /// Schemes worth fetching. Everything else (`mailto:`, `tel:`, `file:`,
  /// `javascript:`, custom app schemes) is rejected outright.
  static const Set<String> allowedSchemes = {'http', 'https'};

  /// Hostnames that always refer to the local machine.
  static const Set<String> _blockedHosts = {
    'localhost',
    'localhost.localdomain',
    'ip6-localhost',
    'ip6-loopback',
    'broadcasthost',
  };

  /// Suffixes reserved for private naming schemes.
  static const Set<String> _blockedSuffixes = {
    '.local',
    '.localhost',
    '.localdomain',
    '.internal',
    '.intranet',
    '.private',
    '.corp',
    '.home',
    '.home.arpa',
    '.lan',
    '.onion',
    '.test',
    '.example',
    '.invalid',
  };

  /// How long to wait for the DNS check before giving up and allowing the
  /// request. The socket layer will resolve the name anyway; this lookup only
  /// exists to catch the private-address case earlier.
  static const Duration _lookupTimeout = Duration(seconds: 3);

  /// Synchronous checks: scheme, hostname shape and literal IP addresses.
  ///
  /// Returns `null` when nothing is wrong.
  static MetadataFetchStatus? check(Uri uri) {
    if (!allowedSchemes.contains(uri.scheme.toLowerCase())) {
      return MetadataFetchStatus.unsupportedScheme;
    }

    final host = uri.host.trim().toLowerCase();
    if (host.isEmpty) return MetadataFetchStatus.invalidUrl;

    if (_blockedHosts.contains(host)) return MetadataFetchStatus.blockedHost;
    for (final suffix in _blockedSuffixes) {
      if (host.endsWith(suffix)) return MetadataFetchStatus.blockedHost;
    }

    // A bare hostname with no dot is a LAN name (`router`, `nas`).
    if (!host.contains('.') && !_looksLikeIpLiteral(host)) {
      return MetadataFetchStatus.blockedHost;
    }

    final literal = _parseIp(host);
    if (literal != null && isPrivateAddress(literal)) {
      return MetadataFetchStatus.blockedHost;
    }

    // `InternetAddress.tryParse` only accepts canonical dotted-quad, but the
    // platform resolver accepts everything `inet_aton` does. Without this,
    // `http://127.1/` and `http://0177.0.0.1/` sail past the check above and
    // are then resolved to loopback by the OS.
    final loose = parseLooseIpv4(host);
    if (loose != null && isPrivateV4Word(loose)) {
      return MetadataFetchStatus.blockedHost;
    }

    // A host made only of digits, dots and hex prefixes is an address attempt.
    // If neither parser could make sense of it, refuse rather than hand it to
    // a resolver whose interpretation we cannot predict.
    if (literal == null && loose == null && looksNumeric(host)) {
      return MetadataFetchStatus.blockedHost;
    }

    return null;
  }

  /// [check] plus a DNS resolution, so that a public hostname pointing at a
  /// private address is also rejected.
  ///
  /// Skipped on web (no socket API) and treated as allowed when the lookup
  /// itself fails — a name that will not resolve is about to fail the request
  /// anyway, and reporting it as "blocked" would be misleading.
  static Future<MetadataFetchStatus?> checkResolved(Uri uri) async {
    final synchronous = check(uri);
    if (synchronous != null) return synchronous;
    if (kIsWeb) return null;

    // A literal address was already validated by [check].
    if (_parseIp(uri.host) != null) return null;

    try {
      final addresses = await InternetAddress.lookup(uri.host).timeout(_lookupTimeout);
      if (addresses.isEmpty) return null;
      // Reject if *any* resolved address is private: a hostname with a mixed
      // record set is exactly the DNS-rebinding shape worth refusing.
      for (final address in addresses) {
        if (isPrivateAddress(address)) return MetadataFetchStatus.blockedHost;
      }
    } catch (_) {
      // Lookup failed, timed out, or the platform has no DNS access. For an
      // ordinary hostname that is harmless — the request is about to fail
      // anyway. For something that looks like an address literal it is not:
      // an attacker who controls the nameserver can stall the lookup to force
      // this path, so those fail closed.
      if (looksNumeric(uri.host)) return MetadataFetchStatus.blockedHost;
    }

    return null;
  }

  /// Whether [host] consists only of characters an address literal can contain.
  ///
  /// Used to decide whether an unparseable, unresolvable host should fail open
  /// (a normal domain) or closed (something pretending to be an address).
  static bool looksNumeric(String host) {
    if (host.isEmpty) return false;
    for (final part in host.split('.')) {
      if (part.isEmpty) continue;
      final body = part.toLowerCase().startsWith('0x') ? part.substring(2) : part;
      if (body.isEmpty) return false;
      for (final unit in body.toLowerCase().codeUnits) {
        final isDigit = unit >= 0x30 && unit <= 0x39;
        final isHex = unit >= 0x61 && unit <= 0x66;
        if (!isDigit && !isHex) return false;
      }
    }
    return true;
  }

  /// Parses the permissive IPv4 forms `inet_aton` accepts, returning the
  /// address as a 32-bit word.
  ///
  /// Handles octal (`0177.0.0.1`), hex (`0x7f.0.0.1`), packed decimal
  /// (`2130706433`) and the short forms (`127.1`, `127.0.1`) where the final
  /// part absorbs the remaining bytes. Returns null when [host] is not an
  /// address in any of those forms.
  static int? parseLooseIpv4(String host) {
    if (host.isEmpty) return null;
    final parts = host.split('.');
    if (parts.isEmpty || parts.length > 4) return null;

    final values = <int>[];
    for (final part in parts) {
      final value = _parsePart(part);
      if (value == null) return null;
      values.add(value);
    }

    // Every part except the last addresses exactly one byte.
    for (var i = 0; i < values.length - 1; i++) {
      if (values[i] > 0xFF) return null;
    }

    // The last part absorbs whatever bytes the earlier parts did not.
    final remainingBytes = 4 - (values.length - 1);
    final maxLast = remainingBytes >= 4 ? 0xFFFFFFFF : (1 << (8 * remainingBytes)) - 1;
    if (values.last > maxLast) return null;

    var word = 0;
    for (var i = 0; i < values.length - 1; i++) {
      word |= values[i] << (8 * (3 - i));
    }
    return (word | values.last) & 0xFFFFFFFF;
  }

  /// [_isPrivateV4] over a packed 32-bit address.
  static bool isPrivateV4Word(int word) => _isPrivateV4((word >> 24) & 0xFF, (word >> 16) & 0xFF);

  static int? _parsePart(String raw) {
    final part = raw.trim();
    if (part.isEmpty) return null;

    final lower = part.toLowerCase();
    if (lower.startsWith('0x')) {
      final digits = lower.substring(2);
      if (digits.isEmpty) return null;
      return int.tryParse(digits, radix: 16);
    }
    if (part.length > 1 && part.startsWith('0')) {
      return int.tryParse(part.substring(1), radix: 8);
    }
    return int.tryParse(part, radix: 10);
  }

  /// Whether [address] is loopback, private, link-local or otherwise not a
  /// public internet destination.
  static bool isPrivateAddress(InternetAddress address) {
    if (address.isLoopback || address.isLinkLocal || address.isMulticast) return true;

    final raw = address.rawAddress;

    if (address.type == InternetAddressType.IPv4 && raw.length == 4) {
      return _isPrivateV4(raw[0], raw[1]);
    }

    if (address.type == InternetAddressType.IPv6 && raw.length == 16) {
      // Unspecified (::) and loopback (::1).
      final isAllZeroPrefix = raw.take(15).every((byte) => byte == 0);
      if (isAllZeroPrefix && (raw[15] == 0 || raw[15] == 1)) return true;

      // Unique local addresses, fc00::/7.
      if ((raw[0] & 0xFE) == 0xFC) return true;

      // Link-local, fe80::/10.
      if (raw[0] == 0xFE && (raw[1] & 0xC0) == 0x80) return true;

      // IPv4-mapped (::ffff:a.b.c.d) — unwrap and apply the v4 rules.
      final isV4Mapped = raw.take(10).every((byte) => byte == 0) && raw[10] == 0xFF && raw[11] == 0xFF;
      if (isV4Mapped) return _isPrivateV4(raw[12], raw[13]);
    }

    return false;
  }

  static bool _isPrivateV4(int first, int second) {
    // 0.0.0.0/8 "this network"
    if (first == 0) return true;
    // 10.0.0.0/8
    if (first == 10) return true;
    // 127.0.0.0/8 loopback
    if (first == 127) return true;
    // 169.254.0.0/16 link-local
    if (first == 169 && second == 254) return true;
    // 172.16.0.0/12
    if (first == 172 && second >= 16 && second <= 31) return true;
    // 192.168.0.0/16
    if (first == 192 && second == 168) return true;
    // 192.0.0.0/24 and 192.0.2.0/24 (IETF protocol assignments / TEST-NET-1)
    if (first == 192 && second == 0) return true;
    // 100.64.0.0/10 carrier-grade NAT
    if (first == 100 && second >= 64 && second <= 127) return true;
    // 198.18.0.0/15 benchmarking
    if (first == 198 && (second == 18 || second == 19)) return true;
    // 224.0.0.0/4 multicast and 240.0.0.0/4 reserved
    if (first >= 224) return true;
    return false;
  }

  static bool _looksLikeIpLiteral(String host) => _parseIp(host) != null;

  static InternetAddress? _parseIp(String host) {
    // A bracketed IPv6 literal arrives from Uri.host without its brackets on
    // some platforms and with them on others.
    final normalized = host.startsWith('[') && host.endsWith(']') ? host.substring(1, host.length - 1) : host;
    try {
      return InternetAddress.tryParse(normalized);
    } catch (_) {
      // universal_io's web stub does not implement address parsing.
      return null;
    }
  }
}
