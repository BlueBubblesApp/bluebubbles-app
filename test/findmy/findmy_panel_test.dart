import 'package:bluebubbles/app/layouts/findmy/findmy_panel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("reads an unattached drawer scroll offset as zero instead of throwing", () {
    final controller = FindMyPanelScrollController();
    addTearDown(controller.dispose);

    expect(controller.hasClients, isFalse);
    expect(controller.offset, 0.0);
  });

  test("opens the drawer halfway", () {
    expect(findMyPanelSnapPoint, 0.5);
  });
}
