import 'package:bluebubbles/services/ui/navigator/navigator_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

Route<void> _route([String? name]) =>
    MaterialPageRoute<void>(builder: (_) => const SizedBox(), settings: RouteSettings(name: name));

/// A route built from the Navigator's pages list, like each pane's placeholder
Route<void> _pageRoute() =>
    MaterialPageRoute<void>(builder: (_) => const SizedBox(), settings: const MaterialPage<void>(child: SizedBox()));

/// Runs a frame, as the navigator's own push or pop would schedule one
Future<void> _frame(WidgetTester tester) {
  tester.binding.scheduleFrame();
  return tester.pump();
}

void main() {
  group('PaneObserver', () {
    testWidgets('ignores routes from the pages list', (tester) async {
      final open = false.obs;
      final observer = PaneObserver(open);

      observer.didPush(_pageRoute(), null);
      await _frame(tester);

      expect(observer.routes, isEmpty);
      expect(open.value, isFalse);
    });

    testWidgets('opens after the frame a page is pushed, and closes when it pops', (tester) async {
      final open = false.obs;
      final observer = PaneObserver(open);
      final page = _route();

      observer.didPush(page, null);
      expect(open.value, isFalse, reason: 'updated after the frame, since navigator callbacks run mid-build');
      await _frame(tester);
      expect(open.value, isTrue);

      observer.didPop(page, null);
      await _frame(tester);
      expect(open.value, isFalse);
    });

    testWidgets('stays open until the last page leaves', (tester) async {
      final open = false.obs;
      final observer = PaneObserver(open);
      final first = _route(), second = _route();

      observer
        ..didPush(first, null)
        ..didPush(second, first);
      await _frame(tester);

      observer.didRemove(first, null);
      await _frame(tester);
      expect(open.value, isTrue);

      observer.didPop(second, null);
      await _frame(tester);
      expect(open.value, isFalse);
    });

    testWidgets('replace keeps the new route in the old one\'s place', (tester) async {
      final observer = PaneObserver(false.obs);
      final first = _route(), second = _route(), replacement = _route();

      observer
        ..didPush(first, null)
        ..didPush(second, first)
        ..didReplace(oldRoute: first, newRoute: replacement);

      expect(observer.routes, [replacement, second]);
    });

    testWidgets('reset forgets pages a discarded navigator never popped', (tester) async {
      final open = false.obs;
      final observer = PaneObserver(open);

      observer.didPush(_route(), null);
      await _frame(tester);
      expect(open.value, isTrue);

      observer.reset();
      await _frame(tester);
      expect(observer.routes, isEmpty);
      expect(open.value, isFalse);
    });
  });

  group('SectionObserver', () {
    test('tracks the topmost section, updated right away', () {
      final open = Rxn<AppSection>();
      final observer = SectionObserver(open);
      final settings = _route(AppSection.settings.name), findMy = _route(AppSection.findMy.name);

      observer.didPush(settings, null);
      expect(open.value, AppSection.settings);

      observer.didPush(findMy, settings);
      expect(open.value, AppSection.findMy);

      observer.didPop(findMy, settings);
      expect(open.value, AppSection.settings);

      observer.didRemove(settings, null);
      expect(open.value, isNull);
    });

    test('ignores routes that are not sections', () {
      final open = Rxn<AppSection>();
      final observer = SectionObserver(open);

      observer
        ..didPush(_route(), null)
        ..didPush(_route('somewhere'), null);

      expect(observer.routes, isEmpty);
      expect(open.value, isNull);
    });
  });
}
