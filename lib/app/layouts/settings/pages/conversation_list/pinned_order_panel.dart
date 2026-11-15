import 'dart:async';

import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/draggable_conversation_tile.dart';
import 'package:bluebubbles/app/wrappers/bb_app_bar.dart';
import 'package:bluebubbles/app/wrappers/bb_scaffold.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PinnedOrderPanel extends StatefulWidget {
  const PinnedOrderPanel({super.key});

  @override
  State<PinnedOrderPanel> createState() => _PinnedOrderPanelState();
}

class _PinnedOrderPanelState extends State<PinnedOrderPanel> {
  List<Chat> _pinnedChats = [];
  bool _loaded = false;
  Worker? _loadedWatcher;

  @override
  void initState() {
    super.initState();
    _loaded = ChatsSvc.loadedFirstChatBatch.value;
    if (_loaded) {
      _pinnedChats = ChatsSvc.getFilteredChats(pinnedOnly: true);
    } else {
      _loadedWatcher = ever(ChatsSvc.loadedFirstChatBatch, (bool loaded) {
        if (loaded && mounted) {
          setState(() {
            _loaded = true;
            _pinnedChats = ChatsSvc.getFilteredChats(pinnedOnly: true);
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _loadedWatcher?.dispose();
    ChatsSvc.refreshSortOrder();
    super.dispose();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final item = _pinnedChats.removeAt(oldIndex);
      _pinnedChats.insert(newIndex, item);
    });

    // Persist new order. Avoid updating reactive pin state here to prevent
    // mid-animation list rebuilds triggered by GetX listener cascades.
    for (var i = 0; i < _pinnedChats.length; i++) {
      _pinnedChats[i].pinIndex = i;
      unawaited(_pinnedChats[i].saveAsync(updatePinIndex: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BBScaffold(
      extendBodyBehindAppBar: false,
      appBar: BBAppBar(
        titleText: "Pinned Chat Order",
        leading: buildBackButton(context),
      ),
      body: !_loaded
          ? Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 50.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "Loading chats...",
                        style: context.theme.textTheme.labelLarge,
                      ),
                    ),
                    buildProgressIndicator(context, size: 15),
                  ],
                ),
              ),
            )
          : _pinnedChats.isEmpty
              ? Center(
                  child: Text(
                    "You have no pinned chats",
                    style: context.theme.textTheme.labelLarge,
                  ),
                )
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  onReorder: _onReorder,
                  header: Padding(
                    padding: const EdgeInsets.fromLTRB(15, 5, 15, 8),
                    child: Text(
                      "Set the order of pinned chats by dragging the handle next to each chat tile.",
                      style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline),
                    ),
                  ),
                  itemBuilder: (context, index) {
                    final chat = _pinnedChats[index];
                    return DecoratedBox(
                      key: Key(chat.guid),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: context.theme.colorScheme.outline.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                      child: DraggableConversationTile(chat: chat, index: index),
                    );
                  },
                  itemCount: _pinnedChats.length,
                ),
    );
  }
}
