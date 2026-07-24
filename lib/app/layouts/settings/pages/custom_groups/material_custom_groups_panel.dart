import 'package:bluebubbles/app/components/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/app/layouts/chat_selector_view/chat_selector_view.dart';
import 'package:bluebubbles/app/layouts/settings/pages/custom_groups/create_group_dialog.dart';
import 'package:bluebubbles/app/layouts/settings/pages/custom_groups/custom_group_options_menu.dart';
import 'package:bluebubbles/app/layouts/settings/pages/custom_groups/custom_groups_controller.dart';
import 'package:bluebubbles/app/wrappers/bb_app_bar.dart';
import 'package:bluebubbles/app/wrappers/bb_scaffold.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MaterialCustomGroupsPanel extends StatefulWidget {
  const MaterialCustomGroupsPanel({super.key});

  @override
  State<MaterialCustomGroupsPanel> createState() => _MaterialCustomGroupsPanelState();
}

class _MaterialCustomGroupsPanelState extends State<MaterialCustomGroupsPanel> {
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
      onDelete: () async {
        if (await _confirmDelete(group)) controller.deleteGroup(group);
      },
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

  Future<bool> _confirmDelete(CustomGroup group) async {
    bool confirmed = false;
    await showAreYouSure(
      context,
      title: "Delete '${group.name}'?",
      content: const Text("This won't delete the chats in it."),
      yesText: "Delete",
      yesColor: context.theme.colorScheme.error,
      yesIsDestructive: true,
      onNo: () => Navigator.of(context, rootNavigator: true).pop(),
      onYes: () {
        confirmed = true;
        Navigator.of(context, rootNavigator: true).pop();
      },
    );
    return confirmed;
  }

  @override
  Widget build(BuildContext context) {
    return BBScaffold(
      extendBodyBehindAppBar: false,
      appBar: BBAppBar(
        titleText: "Custom Groups",
        leading: buildBackButton(context),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onCreate,
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        if (controller.loading.value) return Center(child: buildProgressIndicator(context));
        if (controller.groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("You have no custom groups", style: context.theme.textTheme.labelLarge),
                TextButton(onPressed: _onCreate, child: const Text("Create one")),
              ],
            ),
          );
        }
        return ReorderableListView.builder(
          buildDefaultDragHandles: false,
          onReorder: _onReorder,
          itemCount: controller.groups.length,
          itemBuilder: (context, index) {
            final group = controller.groups[index];
            return Dismissible(
              key: ValueKey(group.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: context.theme.colorScheme.errorContainer,
                child: Icon(Icons.delete_outline, color: context.theme.colorScheme.onErrorContainer),
              ),
              confirmDismiss: (_) => _confirmDelete(group),
              onDismissed: (_) => controller.deleteGroup(group),
              child: ListTile(
                leading: ContactAvatarGroupWidget(
                  handles: _groupHandles(group),
                  size: 40,
                  editable: false,
                ),
                title: Text(group.name),
                subtitle: Text("${group.chats.length} chats"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!group.showUnreadBadge)
                      Tooltip(
                        message: "Unread badge hidden",
                        child: Icon(
                          Icons.notifications_off_outlined,
                          size: 18,
                          color: context.theme.colorScheme.outline,
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      tooltip: "More options",
                      onPressed: () => _onOptions(group),
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: Icon(
                        Icons.drag_handle,
                        color: context.theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
                onTap: () => _onEditChats(group),
              ),
            );
          },
        );
      }),
    );
  }
}
