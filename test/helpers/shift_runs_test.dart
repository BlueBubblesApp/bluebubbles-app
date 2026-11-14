import 'package:bluebubbles/app/components/custom_text_editing_controllers.dart';
import 'package:bluebubbles/database/global/attributed_body.dart';
import 'package:flutter_test/flutter_test.dart';

Run _bold(int start, int length) => Run(
      range: [start, length],
      attributes: Attributes(rawAttributes: {MentionTextEditingController.styleAttributes['bold']!: 1}),
    );

void main() {
  group('shiftRuns', () {
    test('typing after every run keeps the same list', () {
      final runs = [_bold(0, 5)];
      final shifted = MentionTextEditingController.shiftRuns('hello world', 'hello worlds', runs, anchor: 11);
      expect(identical(shifted, runs), isTrue);
    });

    test('typing before a run moves it, in a new list', () {
      final runs = [_bold(6, 5)];
      final shifted = MentionTextEditingController.shiftRuns('hello world', 'oh hello world', runs, anchor: 0);
      expect(identical(shifted, runs), isFalse);
      expect(shifted.single.range, [9, 5]);
    });

    test('typing at the end of a style extends it', () {
      final runs = [_bold(0, 5)];
      final shifted = MentionTextEditingController.shiftRuns('hello', 'hellos', runs, anchor: 5);
      expect(shifted.single.range, [0, 6]);
    });
  });
}
