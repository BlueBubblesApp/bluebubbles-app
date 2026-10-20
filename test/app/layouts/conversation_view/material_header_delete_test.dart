import 'package:bluebubbles/app/layouts/conversation_view/widgets/header/material_header.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  testWidgets('confirmed deletion finishes closing an existing snackbar before preserving a new notice', (
    tester,
  ) async {
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: Text('conversation'))));
    Get.showSnackbar(
      const GetSnackBar(
        message: 'unrelated notice',
        duration: Duration(minutes: 1),
        animationDuration: Duration(milliseconds: 100),
      ),
    );
    await tester.pump();
    expect(Get.isSnackbarOpen, isTrue);

    var deletionStarted = false;
    final result = deleteConversationFromHeader(
      Chat(id: 1, guid: 'chat-guid', hasUnreadMessage: false),
      deleteChat: (_) async {
        deletionStarted = true;
        Get.showSnackbar(
          const GetSnackBar(
            message: 'deletion failed',
            duration: Duration(minutes: 1),
            animationDuration: Duration(milliseconds: 100),
          ),
        );
        return false;
      },
    );

    await tester.pump(const Duration(milliseconds: 200));
    expect(deletionStarted, isTrue);
    expect(await result, isFalse);
    await tester.pump();

    expect(find.text('unrelated notice'), findsNothing);
    expect(find.text('deletion failed'), findsOneWidget);
    expect(Get.isSnackbarOpen, isTrue);

    final cleanup = Get.closeCurrentSnackbar();
    await tester.pump(const Duration(milliseconds: 200));
    await cleanup;
  });
}
