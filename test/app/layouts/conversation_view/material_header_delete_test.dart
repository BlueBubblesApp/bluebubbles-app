import 'dart:async';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/header/material_header.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  testWidgets('confirmed deletion closes an existing snackbar before waiting and preserves the result', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: Text('conversation'))));
    Get.showSnackbar(const GetSnackBar(message: 'unrelated notice', duration: Duration(minutes: 1)));
    await tester.pump();
    expect(Get.isSnackbarOpen, isTrue);

    final deletion = Completer<bool>();
    final result = deleteConversationFromHeader(
      Chat(id: 1, guid: 'chat-guid', hasUnreadMessage: false),
      deleteChat: (_) => deletion.future,
    );

    await tester.pump();
    expect(Get.isSnackbarOpen, isFalse);
    expect(deletion.isCompleted, isFalse);

    deletion.complete(false);
    expect(await result, isFalse);
  });
}
