import 'package:bluebubbles/app/layouts/conversation_list/widgets/pin_drag/chat_draggables.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every pointer kind scrolls, as on Linux and Android.
class _AllDevicesScroll extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}

void main() {
  late int mouseStarts;
  late int touchStarts;
  late ScrollController scroll;

  Future<void> pumpList(WidgetTester tester, {bool anyDirection = false}) async {
    mouseStarts = 0;
    touchStarts = 0;
    scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(MaterialApp(
      scrollBehavior: _AllDevicesScroll(),
      home: Scaffold(
        body: ListView.builder(
          controller: scroll,
          itemCount: 50,
          itemBuilder: (context, index) => TouchChatDraggable(
            data: '$index',
            feedback: const SizedBox.shrink(),
            onDragStarted: () => touchStarts++,
            child: MouseChatDraggable(
              data: '$index',
              feedback: const SizedBox.shrink(),
              anyDirection: anyDirection,
              scrolls: (kind) => ScrollConfiguration.of(context).dragDevices.contains(kind),
              onDragStarted: () => mouseStarts++,
              child: SizedBox(height: 60, child: Text('row $index')),
            ),
          ),
        ),
      ),
    ));
  }

  Future<void> mouseDrag(WidgetTester tester, Offset by) async {
    final gesture = await tester.startGesture(tester.getCenter(find.text('row 3')), kind: PointerDeviceKind.mouse);
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(by / 10);
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('a vertical mouse drag on a row scrolls the list', (tester) async {
    await pumpList(tester);
    await mouseDrag(tester, const Offset(6, -200));
    expect(mouseStarts, 0);
    expect(scroll.offset, greaterThan(0));
  });

  testWidgets('a horizontal mouse drag on a row starts a drag', (tester) async {
    await pumpList(tester);
    await mouseDrag(tester, const Offset(120, -20));
    expect(mouseStarts, 1);
    expect(touchStarts, 0);
    expect(scroll.offset, 0);
  });

  testWidgets('a pin starts a mouse drag in any direction', (tester) async {
    await pumpList(tester, anyDirection: true);
    await mouseDrag(tester, const Offset(0, -200));
    expect(mouseStarts, 1);
    expect(scroll.offset, 0);
  });

  testWidgets('a touch swipe scrolls rather than dragging', (tester) async {
    await pumpList(tester);
    await tester.drag(find.text('row 3'), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(mouseStarts + touchStarts, 0);
    expect(scroll.offset, greaterThan(0));
  });

  testWidgets('a touch hold then drag starts the touch drag', (tester) async {
    await pumpList(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.text('row 3')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(touchStarts, 1);
    expect(mouseStarts, 0);
  });
}
