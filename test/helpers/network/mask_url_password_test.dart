import 'package:flutter_test/flutter_test.dart';
import 'package:bluebubbles/helpers/network/url_utils.dart';

void main() {
  group('maskUrlPassword', () {
    test('masks guid parameter value', () {
      const url = 'https://server.example.com/api/v1/ping?guid=secretpassword123';
      expect(maskUrlPassword(url), 'https://server.example.com/api/v1/ping?guid=***');
    });

    test('masks password parameter value', () {
      const url = 'https://server.example.com/api/v1/ping?password=secretpassword123';
      expect(maskUrlPassword(url), 'https://server.example.com/api/v1/ping?password=***');
    });

    test('masks guid when multiple parameters present (guid first)', () {
      const url = 'https://server.example.com/api/v1/chat/count?guid=mysecret&limit=100&offset=0';
      expect(maskUrlPassword(url), 'https://server.example.com/api/v1/chat/count?guid=***&limit=100&offset=0');
    });

    test('masks guid when multiple parameters present (guid last)', () {
      const url = 'https://server.example.com/api/v1/chat/count?limit=100&offset=0&guid=mysecret';
      expect(maskUrlPassword(url), 'https://server.example.com/api/v1/chat/count?limit=100&offset=0&guid=***');
    });

    test('masks both guid and password when both are present', () {
      const url = 'https://server.example.com/api/v1?guid=abc&password=xyz&other=keep';
      expect(maskUrlPassword(url), 'https://server.example.com/api/v1?guid=***&password=***&other=keep');
    });

    test('leaves URLs without sensitive parameters unchanged', () {
      const url = 'https://server.example.com/api/v1/ping?limit=10&offset=0';
      expect(maskUrlPassword(url), url);
    });

    test('leaves plain strings without URLs unchanged', () {
      const msg = 'Connection refused. Is the server running?';
      expect(maskUrlPassword(msg), msg);
    });

    test('masks guid embedded in an error message string', () {
      const msg =
          'DioException [connection error]: The connection errored: '
          'HttpException: Failed to connect, uri = '
          'https://server.example.com/api/v1/chat/count?guid=secretpassword&other=keep';
      const expected =
          'DioException [connection error]: The connection errored: '
          'HttpException: Failed to connect, uri = '
          'https://server.example.com/api/v1/chat/count?guid=***&other=keep';
      expect(maskUrlPassword(msg), expected);
    });

    test('masks URL-encoded guid value', () {
      const url = 'https://server.example.com/api/v1/ping?guid=my%40secret%21value';
      expect(maskUrlPassword(url), 'https://server.example.com/api/v1/ping?guid=***');
    });

    test('masks case-insensitive parameter names (GUID, Password)', () {
      const url = 'https://server.example.com/api/v1?GUID=secret&PASSWORD=another';
      expect(maskUrlPassword(url), 'https://server.example.com/api/v1?GUID=***&PASSWORD=***');
    });

    test('handles empty guid value without throwing', () {
      const url = 'https://server.example.com/api/v1/ping?guid=';
      expect(maskUrlPassword(url), 'https://server.example.com/api/v1/ping?guid=***');
    });

    test('does not throw on empty string', () {
      expect(maskUrlPassword(''), '');
    });

    test('does not throw on malformed/arbitrary input', () {
      const weirdInputs = [
        'not a url at all ??? &&& ===',
        '?guid',
        '&guid',
        'guid=noQuestionMark',
        '?guid=value#fragment',
      ];
      for (final input in weirdInputs) {
        expect(() => maskUrlPassword(input), returnsNormally);
      }
    });

    test('fragment anchor is not included in masked value', () {
      const url = 'https://server.example.com/api/v1/ping?guid=secret#anchor';
      expect(maskUrlPassword(url), 'https://server.example.com/api/v1/ping?guid=***#anchor');
    });
  });
}
