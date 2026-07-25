import 'package:bluebubbles/models/server_details.dart';
import 'package:bluebubbles/services/network/bluebubbles_backend.dart';
import 'package:flutter_test/flutter_test.dart';

/// Capability parity tests for [BlueBubblesBackend].
///
/// Before the BackendService seam, UI code gated features on raw server facts,
/// e.g. `serverDetails.isMinVentura && serverDetails.supportsEditAndUnsend`.
/// Those expressions now live behind capability getters. These tests pin the
/// *observable answers* for a set of real server/macOS profiles, so a future
/// change to a capability getter that silently alters what the UI shows fails
/// here rather than in someone's chat window.
///
/// Expected values are written out literally rather than derived from the
/// implementation — a test that recomputes the expression it is testing proves
/// nothing.
void main() {
  BlueBubblesBackend backendFor(ServerDetails details, {bool privateApi = true}) =>
      BlueBubblesBackend(serverDetails: () => details, privateApiEnabled: () => privateApi);

  ServerDetails server({required int macOS, int macOSMinor = 0, required int versionCode}) => ServerDetails(
        macOSVersion: macOS,
        macOSMinorVersion: macOSMinor,
        serverVersion: 'test',
        serverVersionCode: versionCode,
      );

  group('capabilities across server profiles', () {
    test('macOS 10.14 Mojave, server v0.1.0 (41) — nothing modern is available', () {
      final b = backendFor(server(macOS: 10, macOSMinor: 14, versionCode: 41));

      expect(b.canEditUnsend, isFalse);
      expect(b.canSchedule, isFalse);
      expect(b.canSendSubject, isFalse);
      expect(b.supportsFocusStates, isFalse);
      expect(b.supportsFindMy, isFalse);
      expect(b.canLeaveChat, isFalse);
      expect(b.canManageGroupChat, isFalse);
      // Pre-Sonoma servers do not build link previews, so the client must.
      expect(b.needsClientSideUrlPreview, isTrue);
    });

    test('macOS 10.15 Catalina, server v1.2.0 (142) — Find My and subjects only', () {
      final b = backendFor(server(macOS: 10, macOSMinor: 15, versionCode: 142));

      expect(b.supportsFindMy, isTrue, reason: 'Catalina is the Find My floor');
      expect(b.canSendSubject, isTrue, reason: 'subject lines landed in v0.3.0 (63)');
      expect(b.canEditUnsend, isFalse, reason: 'needs Ventura and v1.2.6');
      expect(b.canSchedule, isFalse);
      expect(b.supportsFocusStates, isFalse);
      expect(b.canManageGroupChat, isFalse);
    });

    test('macOS 11 Big Sur, server v1.2.6 (148) — edit/unsend still gated on Ventura', () {
      final b = backendFor(server(macOS: 11, versionCode: 148));

      expect(b.canEditUnsend, isFalse, reason: 'server supports it, but macOS is below Ventura');
      expect(b.supportsFindMy, isTrue);
      expect(b.supportsFocusStates, isFalse, reason: 'focus states need Monterey');
      expect(b.canManageGroupChat, isFalse, reason: 'group management needs v1.6.0 (226)');
    });

    test('macOS 12 Monterey, server v1.5.0 (205) — scheduling and focus states', () {
      final b = backendFor(server(macOS: 12, versionCode: 205));

      expect(b.canSchedule, isTrue);
      expect(b.supportsFocusStates, isTrue);
      expect(b.canEditUnsend, isFalse);
      expect(b.canManageGroupChat, isFalse);
    });

    test('macOS 13 Ventura, server v1.6.0 (226) — edit/unsend and group management', () {
      final b = backendFor(server(macOS: 13, versionCode: 226));

      expect(b.canEditUnsend, isTrue);
      expect(b.canSchedule, isTrue);
      expect(b.canLeaveChat, isTrue);
      expect(b.canManageGroupChat, isTrue);
      expect(b.supportsFocusStates, isTrue);
      expect(b.needsClientSideUrlPreview, isTrue, reason: 'still pre-Sonoma');
    });

    test('macOS 14 Sonoma, server v1.8.0 (268) — server-side link previews', () {
      final b = backendFor(server(macOS: 14, versionCode: 268));

      expect(b.needsClientSideUrlPreview, isFalse, reason: 'Sonoma builds previews server-side');
      expect(b.canEditUnsend, isTrue);
      expect(b.canManageGroupChat, isTrue);
    });
  });

  group('private API toggle', () {
    final details = server(macOS: 14, versionCode: 268);

    test('group management and rich send require the private API', () {
      final on = backendFor(details, privateApi: true);
      final off = backendFor(details, privateApi: false);

      expect(on.canLeaveChat, isTrue);
      expect(off.canLeaveChat, isFalse);

      expect(on.canManageGroupChat, isTrue);
      expect(off.canManageGroupChat, isFalse);

      expect(on.supportsRichSend, isTrue);
      expect(off.supportsRichSend, isFalse);
    });

    test('capabilities that do not depend on the private API are unaffected', () {
      final off = backendFor(details, privateApi: false);

      expect(off.canEditUnsend, isTrue);
      expect(off.canSchedule, isTrue);
      expect(off.supportsFindMy, isTrue);
      expect(off.supportsFocusStates, isTrue);
    });
  });

  group('version boundaries are inclusive at the documented floor', () {
    test('scheduling turns on exactly at server v1.5.0 (205)', () {
      expect(backendFor(server(macOS: 13, versionCode: 204)).canSchedule, isFalse);
      expect(backendFor(server(macOS: 13, versionCode: 205)).canSchedule, isTrue);
    });

    test('group management turns on exactly at server v1.6.0 (226)', () {
      expect(backendFor(server(macOS: 13, versionCode: 225)).canManageGroupChat, isFalse);
      expect(backendFor(server(macOS: 13, versionCode: 226)).canManageGroupChat, isTrue);
    });

    test('edit/unsend needs both the Ventura floor and server v1.2.6 (148)', () {
      expect(backendFor(server(macOS: 13, versionCode: 147)).canEditUnsend, isFalse);
      expect(backendFor(server(macOS: 13, versionCode: 148)).canEditUnsend, isTrue);
      expect(backendFor(server(macOS: 12, versionCode: 148)).canEditUnsend, isFalse);
    });

    test('Sonoma flips link-preview responsibility to the server', () {
      expect(backendFor(server(macOS: 13, versionCode: 268)).needsClientSideUrlPreview, isTrue);
      expect(backendFor(server(macOS: 14, versionCode: 268)).needsClientSideUrlPreview, isFalse);
    });
  });

  group('backend-invariant capabilities', () {
    final b = backendFor(server(macOS: 14, versionCode: 268));

    test('uploads are cancellable and SMS forwarding is supported', () {
      expect(b.canCancelUploads, isTrue);
      expect(b.supportsSmsForwarding, isTrue);
    });

    test('deletes are soft — BlueBubbles has no hard-delete path', () {
      expect(b.canHardDelete, isFalse);
    });
  });
}
