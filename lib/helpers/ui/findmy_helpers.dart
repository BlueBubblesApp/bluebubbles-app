import 'package:bluebubbles/services/backend/settings/settings_service.dart';
import 'package:latlong2/latlong.dart';

/// Preset decoy centers spread across continents for redacted mode
const _decoyCenters = <({double lat, double lng})>[
  (lat: 40.7829, lng: -73.9654), // New York
  (lat: 41.8781, lng: -87.6298), // Chicago
  (lat: 64.1466, lng: -21.9426), // Reykjavik
  (lat: -33.8688, lng: 151.2093), // Sydney
  (lat: 19.4326, lng: -99.1332), // Mexico City
  (lat: 35.6762, lng: 139.6503), // Tokyo
  (lat: -23.5505, lng: -46.6333), // São Paulo
  (lat: 28.6139, lng: 77.2090), // New Delhi
  (lat: 52.3676, lng: 4.9041), // Amsterdam
  (lat: -1.2921, lng: 36.8219), // Nairobi
];

/// Check for whether FindMy names and coordinates should be redacted or not
bool shouldRedactFindMyContactInfo() =>
    SettingsSvc.settings.redactedMode.value && SettingsSvc.settings.hideContactInfo.value;

int _stableHash(String input) => input.codeUnits.fold(0, (h, c) => (h * 31 + c) & 0x7fffffff);

/// Stable pseudo-random map point for [key]. Same key always maps to the same decoy location.
LatLng redactedFindMyPoint(String key) {
  final h1 = _stableHash(key);
  final h2 = _stableHash('$key-jitter');
  final center = _decoyCenters[h1 % _decoyCenters.length];
  // ±0.05° scatter (~5 km) so markers sharing a preset don't stack exactly.
  final latJitter = ((h2 % 1000) / 1000.0 - 0.5) * 0.1;
  final lngJitter = (((h2 ~/ 1000) % 1000) / 1000.0 - 0.5) * 0.1;
  return LatLng(center.lat + latJitter, center.lng + lngJitter);
}

/// Returns [redactedFindMyPoint] when contact info is hidden, otherwise the real coordinates.
LatLng resolveFindMyMarkerPoint({
  required String stableKey,
  required double latitude,
  required double longitude,
}) {
  if (shouldRedactFindMyContactInfo()) return redactedFindMyPoint(stableKey);
  return LatLng(latitude, longitude);
}
