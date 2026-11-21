import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether the contact sync would link these two addresses: it matches when their variant sets share an element.
bool _sameNumber(String a, String b) => phoneNumberVariants(a).intersection(phoneNumberVariants(b)).isNotEmpty;

void main() {
  group('phoneNumberVariants', () {
    test('keeps the number with and without a leading +', () {
      expect(phoneNumberVariants('+1 (415) 555-2671'), containsAll(['+14155552671', '14155552671']));
      expect(phoneNumberVariants('14155552671'), containsAll(['14155552671', '+14155552671']));
      expect(phoneNumberVariants(''), isEmpty);
    });

    test('a short code yields only itself', () {
      expect(phoneNumberVariants('32789'), {'32789', '+32789'});
      expect(phoneNumberVariants('311'), {'311', '+311'});
    });
  });

  group('matching numbers', () {
    test('a number matches itself however it is formatted', () {
      expect(_sameNumber('+14155552671', '(415) 555-2671'), isTrue);
      expect(_sameNumber('32789', '32789'), isTrue);
      expect(_sameNumber('32789', '+32789'), isTrue);
    });

    test('a country code may be missing on either side', () {
      // US: +1 on the handle, bare 10 digits on the contact, and the other way round
      expect(_sameNumber('+14155552671', '4155552671'), isTrue);
      expect(_sameNumber('4155552671', '+14155552671'), isTrue);
      // UK: contact saved in national format with the 0 trunk prefix
      expect(_sameNumber('+447488874111', '07488 874111'), isTrue);
      // Hong Kong (3-digit country code, 8-digit number) and Iceland (7-digit national numbers)
      expect(_sameNumber('+85291234567', '9123 4567'), isTrue);
      expect(_sameNumber('+3545551234', '555 1234'), isTrue);
    });

    test('unrelated short codes that share their last digits do not match', () {
      // Each pair used to collide once 1-3 leading digits were stripped from both sides
      expect(_sameNumber('32789', '73889'), isFalse); // both "89"
      expect(_sameNumber('22709', '20109'), isFalse); // both "09" (#3319)
      expect(_sameNumber('89808', '74608'), isFalse); // both "08" (#3319)
      expect(_sameNumber('1511', '4151'), isFalse); // both "51"
      expect(_sameNumber('911', '4121'), isFalse); // both "1"
    });

    test('a short code does not match a full number ending in it', () {
      expect(_sameNumber('32789', '+1 212 553 2789'), isFalse);
      expect(_sameNumber('5000', '1-800-MY-APPLE'), isFalse);
    });

    test('different full numbers do not match', () {
      expect(_sameNumber('+14155552671', '+14155552672'), isFalse);
      expect(_sameNumber('+14155552671', '+16465552671'), isFalse);
    });
  });
}
