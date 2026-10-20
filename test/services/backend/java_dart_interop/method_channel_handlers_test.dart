import 'package:bluebubbles/services/backend/java_dart_interop/method_channel_handlers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMethodChannelService implements MethodChannelServiceDelegate {
  @override
  bool headless = true;

  @override
  bool isRunning = false;

  @override
  Uint8List? previousArt;

  @override
  bool shouldIgnoreMessage = false;
}

void main() {
  test('chat-deleted requests retry when the payload is absent', () async {
    final handlers = MethodChannelHandlers(_FakeMethodChannelService());

    final result = await handlers.handle(const MethodCall('chat-deleted'), null);

    expect(result, isFalse);
  });
}
