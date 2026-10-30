import 'dart:async';

import 'package:bluebubbles/app/layouts/findmy/findmy_scroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> select(WidgetTester tester, StateSetter setState, List<GlobalKey> keys, int index) async {
    setState(() {});
    unawaited(ensureFindMyRowVisibleAfterExpansion(keys[index]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 217));
    await tester.pumpAndSettle();
  }

  testWidgets('second selected row is visible after first card collapses', (tester) async {
    final keys = List.generate(8, (_) => GlobalKey());
    int selected = -1;
    late StateSetter setState;

    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          key: const Key('viewport'),
          height: 420,
          child: StatefulBuilder(builder: (context, update) {
            setState = update;
            return ListView.builder(
              itemCount: keys.length,
              itemBuilder: (context, index) => AnimatedSize(
                key: keys[index],
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                child: SizedBox(height: selected == index ? 220 : 72, child: Text('row $index')),
              ),
            );
          }),
        ),
      ),
    ));

    setState(() => selected = 3);
    await select(tester, setState, keys, 3);
    setState(() => selected = 4);
    await select(tester, setState, keys, 4);

    final viewportTop = tester.getTopLeft(find.byKey(const Key('viewport'))).dy;
    final selectedTop = tester.getTopLeft(find.byKey(keys[4])).dy;
    expect(selectedTop, greaterThanOrEqualTo(viewportTop));
    expect(selectedTop, lessThan(viewportTop + 32));
  });

  testWidgets('selected row scrolls the outer drawer when its inner list cannot scroll', (tester) async {
    final keys = List.generate(8, (_) => GlobalKey());
    int selected = -1;
    late StateSetter setState;

    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          key: const Key('nested-viewport'),
          height: 420,
          child: StatefulBuilder(builder: (context, update) {
            setState = update;
            return CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
                SliverToBoxAdapter(
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: keys.length,
                    itemBuilder: (context, index) => AnimatedSize(
                      key: keys[index],
                      duration: const Duration(milliseconds: 200),
                      alignment: Alignment.topCenter,
                      child: SizedBox(height: selected == index ? 220 : 72, child: Text('nested row $index')),
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    ));

    setState(() => selected = 3);
    await select(tester, setState, keys, 3);
    setState(() => selected = 4);
    await select(tester, setState, keys, 4);

    final viewportTop = tester.getTopLeft(find.byKey(const Key('nested-viewport'))).dy;
    final selectedTop = tester.getTopLeft(find.byKey(keys[4])).dy;
    expect(selectedTop, greaterThanOrEqualTo(viewportTop));
    expect(selectedTop, lessThan(viewportTop + 32));
  });
}
