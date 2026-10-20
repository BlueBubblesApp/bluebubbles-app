import 'package:bluebubbles/app/layouts/findmy/findmy_camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

// Reference points; only their relative distances matter.
const seattle = LatLng(47.6062, -122.3321);
const bellevue = LatLng(47.6101, -122.2015);
const redmond = LatLng(47.6740, -122.1215);
const kirkland = LatLng(47.6769, -122.2060);
const dallas = LatLng(32.7767, -96.7970);
const plano = LatLng(33.0198, -96.6989);
const frisco = LatLng(33.1507, -96.8236);
const arlington = LatLng(32.7357, -97.1081);
const austin = LatLng(30.2672, -97.7431);
const miami = LatLng(25.7617, -80.1918);
const montana = LatLng(46.8721, -113.9940);

void main() {
  group("selectFindMyInitialCenter", () {
    test("uses a marker immediately while GPS is unresolved", () {
      expect(selectFindMyInitialCenter(currentLocation: null, markerCenter: dallas), dallas);
    });

    test("prefers the current location once GPS resolves", () {
      expect(selectFindMyInitialCenter(currentLocation: seattle, markerCenter: dallas), seattle);
    });

    test("has no center when neither GPS nor a marker is available", () {
      expect(selectFindMyInitialCenter(currentLocation: null, markerCenter: null), isNull);
    });
  });

  group('selectFindMyCameraFocus without an anchor', () {
    test('opens on the clear majority and leaves a lone outlier out', () {
      final focus = selectFindMyCameraFocus([seattle, bellevue, redmond, kirkland, dallas]);
      expect(focus, unorderedEquals([seattle, bellevue, redmond, kirkland]));
    });

    test('fits everything when two groups are the same size', () {
      final focus = selectFindMyCameraFocus([seattle, bellevue, dallas, plano]);
      expect(focus, unorderedEquals([seattle, bellevue, dallas, plano]));
    });

    test('fits both when there are only two far-apart locations', () {
      expect(selectFindMyCameraFocus([seattle, dallas]), unorderedEquals([seattle, dallas]));
    });

    test('keeps a single location', () {
      expect(selectFindMyCameraFocus([dallas]), [dallas]);
    });

    test('is empty with no locations', () {
      expect(selectFindMyCameraFocus([]), isEmpty);
    });
  });

  group('selectFindMyCameraFocus with an anchor', () {
    test('frames the anchor with nearby friends and leaves distant ones out', () {
      final focus = selectFindMyCameraFocus([plano, frisco, arlington, austin, miami], anchor: dallas);
      expect(focus, unorderedEquals([dallas, plano, frisco, arlington]));
    });

    test('frames only the anchor when nobody is nearby', () {
      expect(selectFindMyCameraFocus([dallas, plano, seattle], anchor: montana), [montana]);
    });

    test('frames only the anchor with no friends', () {
      expect(selectFindMyCameraFocus([], anchor: montana), [montana]);
    });
  });

  test('frames a home friend cluster but not friends hundreds of miles away', () {
    // A few hundred miles away should never count as nearby.
    const houston = LatLng(29.7604, -95.3698);
    final focus = selectFindMyCameraFocus([plano, frisco, houston, seattle], anchor: dallas);
    expect(focus, unorderedEquals([dallas, plano, frisco]));
  });

  test('clusterFindMyPoints keeps a metro area together', () {
    final clusters = clusterFindMyPoints([dallas, plano, frisco, arlington]);
    expect(clusters, hasLength(1));
  });

  group('summarizeFindMyGroup', () {
    test('shows both members of a two-product group without a remainder', () {
      final summary = summarizeFindMyGroup(['phone', 'laptop']);
      expect(summary.visible, ['phone', 'laptop']);
      expect(summary.remaining, 0);
    });

    test('shows two members and counts only the hidden remainder', () {
      final summary = summarizeFindMyGroup(['phone', 'laptop', 'watch', 'tablet', 'headphones', 'wallet']);
      expect(summary.visible, ['phone', 'laptop']);
      expect(summary.remaining, 4);
    });
  });

  group('findMyMarkerIdentity', () {
    test('preserves a non-empty Apple identifier', () {
      expect(findMyMarkerIdentity(stableId: 'apple-id', fallbackObject: Object()), 'apple-id');
    });

    test('returns the same fallback for the same anonymous record', () {
      final record = Object();
      expect(
        findMyMarkerIdentity(stableId: null, fallbackObject: record),
        findMyMarkerIdentity(stableId: null, fallbackObject: record),
      );
    });

    test('keeps separate anonymous records distinct', () {
      expect(
        findMyMarkerIdentity(stableId: null, fallbackObject: Object()),
        isNot(findMyMarkerIdentity(stableId: null, fallbackObject: Object())),
      );
    });
  });

  group('groupFindMyMarkersForZoom', () {
    Marker marker(String id, LatLng point) =>
        Marker(key: ValueKey(id), point: point, width: 30, height: 35, child: const SizedBox());
    MapCamera camera(double zoom) => MapCamera(
      crs: const Epsg3857(),
      center: dallas,
      zoom: zoom,
      rotation: 0,
      nonRotatedSize: const Size(1080, 1200),
    );

    test('groups colliding products while zoomed out regardless of owner', () {
      final groups = groupFindMyMarkersForZoom([
        marker('mine', dallas),
        marker('family', const LatLng(32.77675, -96.79705)),
        marker('away', plano),
      ], camera(13));
      expect(groups.map((group) => group.map((e) => (e.key as ValueKey).value).toList()), [
        ['mine', 'family'],
        ['away'],
      ]);
    });

    test('keeps every product individual at detail zoom even when coordinates overlap', () {
      final groups = groupFindMyMarkersForZoom([
        marker('mine', dallas),
        marker('family', dallas),
      ], camera(findMyDetailZoom));
      expect(groups.map((group) => group.length), [1, 1]);
    });
  });
}
