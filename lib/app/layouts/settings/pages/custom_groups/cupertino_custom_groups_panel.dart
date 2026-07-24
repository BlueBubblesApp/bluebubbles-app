import 'package:bluebubbles/app/components/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/app/layouts/chat_selector_view/chat_selector_view.dart';
import 'package:bluebubbles/app/layouts/settings/pages/custom_groups/create_group_dialog.dart';
import 'package:bluebubbles/app/layouts/settings/pages/custom_groups/custom_group_options_menu.dart';
import 'package:bluebubbles/app/layouts/settings/pages/custom_groups/custom_groups_controller.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/content/next_button.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';

class CupertinoCustomGroupsPanel extends StatefulWidget {
  const CupertinoCustomGroupsPanel({super.key});

  @override
  State<CupertinoCustomGroupsPanel> createState() => _CupertinoCustomGroupsPanelState();
}

class _CupertinoCustomGroupsPanelState extends State<CupertinoCustomGroupsPanel> with ThemeHelpers {
  final CustomGroupsController controller = Get.find<CustomGroupsController>();

  Future<void> _onCreate() async {
    final name = await showCreateGroupDialog(context);
    if (name == null || name.isEmpty) return;
    if (!mounted) return;
    final chats = await Navigator.of(context).push<List<Chat>>(
      MaterialPageRoute(
        builder: (_) => ChatSelectorView(
          multiSelect: true,
          onMultiSelect: (_) {},
        ),
      ),
    );
    if (chats == null) return;
    await controller.createGroup(name, chats.map((c) => c.guid).toList());
  }

  Future<void> _onEditChats(CustomGroup group) async {
    final chats = await Navigator.of(context).push<List<Chat>>(
      MaterialPageRoute(
        builder: (_) => ChatSelectorView(
          multiSelect: true,
          initialSelection: group.chats.map((c) => c.guid).toList(),
          onMultiSelect: (_) {},
        ),
      ),
    );
    if (chats == null) return;
    await controller.updateGroupChats(group, chats.map((c) => c.guid).toList());
  }

  void _onDelete(CustomGroup group) {
    showAreYouSure(
      context,
      title: "Delete '${group.name}'?",
      content: const Text("This won't delete the chats in it."),
      yesText: "Delete",
      yesColor: context.theme.colorScheme.error,
      yesIsDestructive: true,
      onNo: () => Navigator.of(context, rootNavigator: true).pop(),
      onYes: () {
        Navigator.of(context, rootNavigator: true).pop();
        controller.deleteGroup(group);
      },
    );
  }

  Future<void> _onRename(CustomGroup group) async {
    final name = await showCreateGroupDialog(context, initialName: group.name);
    if (name == null || name.isEmpty || !mounted) return;
    await controller.renameGroup(group, name);
  }

  void _onOptions(CustomGroup group) {
    showCustomGroupOptionsMenu(
      context,
      group: group,
      onRename: () => _onRename(group),
      onEditChats: () => _onEditChats(group),
      onToggleUnreadBadge: () => controller.setShowUnreadBadge(group, !group.showUnreadBadge),
      onDelete: () => _onDelete(group),
    );
  }

  List<Handle> _groupHandles(CustomGroup group) {
    final seen = <String>{};
    final handles = <Handle>[];
    for (final chat in group.chats) {
      for (final handle in chat.handles) {
        if (seen.add(handle.address)) handles.add(handle);
      }
    }
    return handles;
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final newOrder = controller.groups.toList();
    final group = newOrder.removeAt(oldIndex);
    newOrder.insert(newIndex, group);
    controller.reorderGroups(newOrder);
  }

  Widget _buildGroupRow(CustomGroup group, int index) {
    return Slidable(
      key: ValueKey(group.id),
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            label: 'Delete',
            backgroundColor: Colors.red,
            icon: CupertinoIcons.trash,
            onPressed: (_) => _onDelete(group),
          ),
        ],
      ),
      child: SettingsTile(
        backgroundColor: tileColor,
        title: group.name,
        subtitle: "${group.chats.length} ${group.chats.length == 1 ? 'chat' : 'chats'}",
        onTap: () => _onEditChats(group),
        leading: ContactAvatarGroupWidget(
          handles: _groupHandles(group),
          size: 30,
          editable: false,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!group.showUnreadBadge)
              Tooltip(
                message: "Unread badge hidden",
                child: Icon(
                  CupertinoIcons.bell_slash_fill,
                  size: 16,
                  color: context.theme.colorScheme.outline,
                ),
              ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _onOptions(group),
              child: Icon(CupertinoIcons.ellipsis_circle, color: context.theme.colorScheme.onSurfaceVariant),
            ),
            const NextButton(),
            const SizedBox(width: 12),
            ReorderableDragStartListener(
              index: index,
              child: Icon(
                CupertinoIcons.line_horizontal_3,
                color: context.theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final groups = controller.groups;
      return SettingsScaffold(
        title: "Custom Groups",
        initialHeader: null,
        iosSubtitle: iosSubtitle,
        materialSubtitle: materialSubtitle,
        tileColor: tileColor,
        headerColor: headerColor,
        actions: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: _onCreate,
            child: Icon(CupertinoIcons.add, color: context.theme.colorScheme.onSurface),
          ),
        ],
        bodySlivers: [
          SliverToBoxAdapter(
            child: controller.loading.value
                ? Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(child: buildProgressIndicator(context)),
                  )
                : groups.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("You have no custom groups", style: context.theme.textTheme.labelLarge),
                              const SizedBox(height: 4),
                              CupertinoButton(onPressed: _onCreate, child: const Text("Create one")),
                            ],
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          onReorder: _onReorder,
                          itemCount: groups.length,
                          itemBuilder: (context, index) => Column(
                            key: ValueKey(groups[index].id),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildGroupRow(groups[index], index),
                              if (index < groups.length - 1) const SettingsDivider(),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      );
    });
  }
}
