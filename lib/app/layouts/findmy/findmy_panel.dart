import 'package:flutter/widgets.dart';
import 'package:sliding_up_panel2/sliding_up_panel2.dart';

/// Fraction of the drawer's travel where it rests halfway open.
const double findMyPanelSnapPoint = 0.5;

/// Scroll controller for the Find My drawer itself. The drawer never scrolls its
/// own content (each tab has its own controller), yet sliding_up_panel2 reads
/// this offset whenever the drag handle is touched, which throws without a
/// client and skips the start of the drag's velocity tracking.
class FindMyPanelScrollController extends ScrollController {
  @override
  double get offset => hasClients ? super.offset : 0.0;
}

/// Find My opens with the drawer halfway, as Apple's does. sliding_up_panel2 can
/// only start fully open or closed, so move it once the panel has attached.
void openFindMyPanelAtSnapPoint(PanelController panelController) {
  if (panelController.isAttached) panelController.panelPosition = findMyPanelSnapPoint;
}
