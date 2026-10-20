import 'package:bluebubbles/app/layouts/findmy/findmy_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatFindMyDistance', () {
    test('says Nearby under a tenth of a mile', () {
      expect(formatFindMyDistance(100, useMiles: true), 'Nearby');
    });

    test('shows one decimal under ten miles', () {
      expect(formatFindMyDistance(3862, useMiles: true), '2.4 mi');
    });

    test('shows whole miles with separators from ten miles up', () {
      expect(formatFindMyDistance(2673000, useMiles: true), '1,661 mi');
    });

    test('uses kilometres outside mile locales', () {
      expect(formatFindMyDistance(3862, useMiles: false), '3.9 km');
      expect(formatFindMyDistance(25000, useMiles: false), '25 km');
    });
  });

  group('formatFindMyAge', () {
    final now = DateTime(2026, 10, 8, 12);

    test('says Now within the last minute', () {
      expect(formatFindMyAge(now.subtract(const Duration(seconds: 40)), now: now), 'Now');
    });

    test('counts minutes under an hour', () {
      expect(formatFindMyAge(now.subtract(const Duration(minutes: 3)), now: now), '3 min. ago');
    });

    test('counts hours under a day', () {
      expect(formatFindMyAge(now.subtract(const Duration(hours: 5)), now: now), '5 hr. ago');
    });

    test('says Yesterday for the previous calendar day', () {
      expect(formatFindMyAge(DateTime(2026, 10, 7, 9), now: now), 'Yesterday');
    });

    test('shows the date for anything older', () {
      expect(formatFindMyAge(DateTime(2026, 10, 1, 9), now: now), '10/1/26');
    });

    test('treats a future timestamp as Now', () {
      expect(formatFindMyAge(now.add(const Duration(minutes: 2)), now: now), 'Now');
    });
  });

  group('findMyUsesMiles', () {
    test('uses miles in the US and UK', () {
      expect(findMyUsesMiles('US'), isTrue);
      expect(findMyUsesMiles('GB'), isTrue);
    });

    test('uses kilometres elsewhere and when the region is unknown', () {
      expect(findMyUsesMiles('IN'), isFalse);
      expect(findMyUsesMiles(null), isFalse);
    });
  });

  group('joinFindMyParts', () {
    test('joins the non-empty parts with a middle dot', () {
      expect(joinFindMyParts(['Plano, TX', null, '', 'Now']), 'Plano, TX · Now');
    });
  });
}
