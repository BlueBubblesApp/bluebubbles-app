import 'package:bluebubbles/helpers/helpers.dart';
import 'package:universal_io/io.dart';
import 'package:bluebubbles/services/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

bool hasBadCert = false;
bool hasPinnedCert = false;


class BadCertOverride extends HttpOverrides {
  @override
  createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      // If there is a bad certificate callback, override it if the host is part of
      // your server URL
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {

        // Check if certificate is pinned
        if (ss.settings.pinnedCertificateSHAs.isNotEmpty){
          hasPinnedCert = _validateCertificatePin(cert, host, port);
          return hasPinnedCert;
        } else {
          // Default to logic that checks hostname
          hasBadCert = _serverUrlValidationCallback(cert, host, port);
          return hasBadCert;
        }
     };
  }
}

bool _serverUrlValidationCallback(X509Certificate cert, String host, int port){
  String serverUrl = sanitizeServerAddress() ?? "";
  if (host.startsWith("*")) {
    final regex = RegExp(
        "^((\\*|[\\w\\d]+(-[\\w\\d]+)*)\\.)*(${host.split(".").reversed.take(2).toList().reversed.join(".")})\$");
    return regex.hasMatch(serverUrl);
  } else {
    return serverUrl.endsWith(host);
  }
}

bool _validateCertificatePin(X509Certificate cert, String host, int port) {
  final pinnedSHAs = ss.settings.pinnedCertificateSHAs;

  if (pinnedSHAs.isEmpty) {
    print('No certificate pins configured - rejecting connection');
    return false;
  }

  try {
    final certHash = _getCertificateHash(cert);

    if (pinnedSHAs.values.contains(certHash)){
      print("Certificate pin exists for $host:$port, accepting connection");
      return true;
    }

    print('Certificate pinning failed for $host:$port');
    print('Expected one of: ${pinnedSHAs.values}');
    print('Got: $certHash');

    return false;
  } catch (e) {
    print('Certificate validation error: $e');
    return false;
  }
}

// Get Certificate
String _getCertificateHash(X509Certificate cert) {
  final certBytes = cert.der;
  final hash = sha256.convert(certBytes);
  return base64.encode(hash.bytes);
}