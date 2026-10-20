import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets("keeps two initials on one line in a marker smaller than the avatar", (tester) async {
    // Find My map markers give the avatar a 35 px circle (≈29 px inside its
    // padding) while the initials are sized for a 40 px avatar.
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 29,
            height: 29,
            child: ContactAvatarInitials(initials: "MW", size: 40, color: Colors.white, textKey: Key("t")),
          ),
        ),
      ),
    );

    final text = tester.renderObject<RenderParagraph>(find.byKey(const Key("t")));
    expect(text.maxLines, 1);
    expect(text.softWrap, isFalse);
    expect(text.didExceedMaxLines, isFalse);
    // The text lays out at its natural width and FittedBox scales it down, so
    // measure the painted box (getRect applies the transform), not the layout size.
    expect(tester.getRect(find.byKey(const Key("t"))).width, lessThanOrEqualTo(29.0 + 0.01));
    expect(tester.takeException(), isNull);
  });
}
