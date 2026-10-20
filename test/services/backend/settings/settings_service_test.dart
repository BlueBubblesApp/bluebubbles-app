import 'package:bluebubbles/services/backend/settings/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldSuppressAndroidAppUpdate', () {
    test('suppresses a desktop release before parsing its nonnumeric code', () {
      expect(
        shouldSuppressAndroidAppUpdate(
          releaseCode: 'desktop.93',
          currentBuildCode: '92',
          ignoredReleaseCode: '',
          isDesktopRelease: true,
        ),
        isTrue,
      );
    });
  });
}
