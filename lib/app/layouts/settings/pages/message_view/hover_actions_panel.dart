import 'package:bluebubbles/app/components/bb_switch.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/details_menu_action.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Pick up to [maxActions] of [choices] to show in the desktop hover bar, and their order.
class HoverActionsPanel extends StatefulWidget {
  const HoverActionsPanel({super.key});

  static const maxActions = 3;

  /// The details menu actions that work as one-click hover actions.
  static const choices = [
    DetailsMenuAction.Reply,
    DetailsMenuAction.CopyText,
    DetailsMenuAction.CopySelection,
    DetailsMenuAction.Forward,
    DetailsMenuAction.Edit,
    DetailsMenuAction.RemindLater,
    DetailsMenuAction.Bookmark,
  ];

  @override
  State<StatefulWidget> createState() => _HoverActionsPanelState();
}

class _HoverActionsPanelState extends State<HoverActionsPanel> with ThemeHelpers {
  /// Picked actions first, in order, then the rest
  late final RxList<DetailsMenuAction> actions = RxList([
    ...SettingsSvc.settings.hoverMenuActions,
    ...HoverActionsPanel.choices.whereNot(SettingsSvc.settings.hoverMenuActions.contains),
  ]);
  late final RxList<DetailsMenuAction> picked = RxList(SettingsSvc.settings.hoverMenuActions);

  void _save() => SettingsSvc.settings.setHoverMenuActions(actions.where(picked.contains).toList());

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: "Hover Actions",
      initialHeader: "Actions",
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      headerColor: headerColor,
      tileColor: tileColor,
      bodySlivers: [
        SliverList(
          delegate: SliverChildListDelegate([
            SettingsSection(
              backgroundColor: tileColor,
              children: [
                const SettingsSubtitle(
                  subtitle:
                      "Hovering over a message shows its tapbacks and up to ${HoverActionsPanel.maxActions} "
                      "of these actions. Drag to reorder.",
                ),
                Obx(() {
                  final list = actions.toList();
                  final on = picked.toList();
                  return ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: list.length,
                    onReorder: (start, end) {
                      actions.insert(end > start ? end - 1 : end, actions.removeAt(start));
                      _save();
                    },
                    itemBuilder: (context, index) {
                      final action = list[index];
                      final isOn = on.contains(action);
                      return ListTile(
                        key: ValueKey(action),
                        leading: Icon(iOS ? action.iosIcon : action.nonIosIcon),
                        title: Text(action.text),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BBSwitch(
                              value: isOn,
                              onChanged: !isOn && on.length >= HoverActionsPanel.maxActions
                                  ? null
                                  : (value) {
                                      value ? picked.add(action) : picked.remove(action);
                                      _save();
                                    },
                            ),
                            ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle)),
                          ],
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          ]),
        ),
      ],
    );
  }
}
