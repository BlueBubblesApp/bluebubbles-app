import 'package:bluebubbles/app/components/bb_switch.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/hover_action.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/widgets/hover_reaction_bar.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Enable/disable and reorder the quick actions in the desktop hover bar beside a message.
///
/// The list is every action, in the user's order — enabled ones first, then the disabled ones; the switch controls
/// whether it is included in the saved (enabled) list.
class HoverActionsPanel extends StatefulWidget {
  const HoverActionsPanel({super.key});

  @override
  State<StatefulWidget> createState() => _HoverActionsPanelState();
}

class _HoverActionsPanelState extends State<HoverActionsPanel> with ThemeHelpers {
  /// All actions in display order
  final RxList<HoverAction> actionList = RxList();

  /// Enabled actions, in display order
  final RxList<HoverAction> enabled = RxList();

  @override
  void initState() {
    super.initState();
    _load(SettingsSvc.settings.hoverActions);
  }

  void _load(List<HoverAction> saved) {
    enabled.value = saved.toList();
    actionList.value = [...saved, ...HoverAction.values.whereNot(saved.contains)];
  }

  /// Keeps the enabled list in the same order as the full list, then persists it
  void _save() {
    enabled.value = actionList.where(enabled.contains).toList();
    SettingsSvc.settings.setHoverActions(enabled.toList());
  }

  /// The real bar, with the enabled actions, on the conversation background
  Widget _preview(BuildContext context) {
    return Container(
      color: context.theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: enabled.isEmpty
          ? Text("The hover bar is turned off",
              style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline))
          : AbsorbPointer(child: HoverReactionBar(actions: enabled.toList(), onMore: () {})),
    );
  }

  Widget _row(BuildContext context, List<HoverAction> list, List<HoverAction> on, int index) {
    final action = list[index];
    return Column(
      key: ValueKey(action),
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(action.icon, color: context.theme.colorScheme.outline),
              const SizedBox(width: 16),
              Expanded(child: Text(action.label, style: context.theme.textTheme.bodyLarge)),
              BBSwitch(
                value: on.contains(action),
                onChanged: (on) {
                  on ? enabled.add(action) : enabled.remove(action);
                  _save();
                },
              ),
              const SizedBox(width: 8),
              ReorderableDragStartListener(
                index: index,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Icon(Icons.drag_handle, color: context.theme.colorScheme.outline),
                ),
              ),
            ],
          ),
        ),
        if (index < list.length - 1) const SettingsDivider(padding: EdgeInsets.only(left: 56)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: "Hover Actions",
      initialHeader: "Preview",
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      headerColor: headerColor,
      tileColor: tileColor,
      actions: [
        TextButton(
          child: Text("Reset",
              style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
          onPressed: () {
            SettingsSvc.settings.resetHoverActions();
            _load(defaultHoverActions);
          },
        ),
      ],
      bodySlivers: [
        SliverList(
          delegate: SliverChildListDelegate([
            SettingsSection(
              backgroundColor: tileColor,
              children: [
                const SettingsSubtitle(
                  subtitle: "Choose which actions appear beside a message when you hover over it, and drag to reorder "
                      "them. Each action only appears on messages where it's available, e.g. tapbacks need Private API "
                      "and an iMessage chat. The ⋯ button to open the full menu is always shown.",
                ),
                Obx(() => _preview(context)),
              ],
            ),
            SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Actions"),
            SettingsSection(
              backgroundColor: tileColor,
              children: [
                Obx(() {
                  // Read the observables here — the list builds its rows lazily, outside Obx's tracking
                  final list = actionList.toList();
                  final on = enabled.toList();
                  return ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: list.length,
                    onReorder: (start, end) {
                      if (start == end) return;
                      final action = actionList.removeAt(start);
                      actionList.insert(end > start ? end - 1 : end, action);
                      _save();
                    },
                    itemBuilder: (context, index) => _row(context, list, on, index),
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
