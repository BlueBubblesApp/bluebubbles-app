import 'dart:async';

import 'package:bluebubbles/app/components/bb_chip.dart';
import 'package:bluebubbles/app/layouts/chat_creator/widgets/chat_creator_tile.dart';
import 'package:bluebubbles/app/wrappers/bb_app_bar.dart';
import 'package:bluebubbles/app/wrappers/bb_scaffold.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart' hide Response;
import 'package:slugify/slugify.dart';

enum ChatSelectorFilter { all, selected, unselected }

class ChatSelectorView extends StatefulWidget {
  const ChatSelectorView({
    super.key,
    this.onSelect,
    this.onMultiSelect,
    this.multiSelect = false,
    this.initialSelection = const <String>[],
  }) : assert(
          (multiSelect && onMultiSelect != null) || (!multiSelect && onSelect != null),
          'Provide onSelect for single-select or onMultiSelect for multiSelect mode',
        );

  final void Function(Chat)? onSelect;
  final void Function(List<Chat>)? onMultiSelect;
  final bool multiSelect;

  /// Chat guids to pre-select when [multiSelect] is true.
  final List<String> initialSelection;

  @override
  ChatSelectorViewState createState() => ChatSelectorViewState();
}

class ChatSelectorViewState extends State<ChatSelectorView> with ThemeHelpers {
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchNode = FocusNode();
  final ScrollController addressScrollController = ScrollController();

  List<Chat> filteredChats = [];
  String? oldSearch;
  Timer? _debounce;
  late Set<String> selectedGuids = widget.initialSelection.toSet();
  ChatSelectorFilter selectionFilter = ChatSelectorFilter.all;

  @override
  void initState() {
    super.initState();

    // Handle searching for a chat
    searchController.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () async {
        final searchChats = await SchedulerBinding.instance.scheduleTask(() async {
          final query = slugify(searchController.text, delimiter: "");
          return ChatsSvc.searchChats(query);
        }, Priority.animation);

        _debounce = null;
        setState(() {
          filteredChats = List<Chat>.from(searchChats);
        });
      });
    });

    if (ChatsSvc.loadedAllChats.isCompleted) {
      if (mounted) {
        setState(() {
          filteredChats = ChatsSvc.allChats;
        });
      }
    } else {
      ChatsSvc.loadedAllChats.future.then((_) {
        if (mounted) {
          setState(() {
            filteredChats = ChatsSvc.allChats;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BBScaffold(
      safeAreaTop: true,
      appBar: BBAppBar(
        titleText: "Select a Chat",
        leading: buildBackButton(context),
        backgroundColor: Colors.transparent,
        toolbarHeight: kIsDesktop ? 90 : 50,
        actions: widget.multiSelect
            ? [
                TextButton(
                  onPressed: () {
                    final selected = filteredChats.where((c) => selectedGuids.contains(c.guid)).toList();
                    widget.onMultiSelect!(selected);
                    Navigator.of(context).pop(selected);
                  },
                  child: const Text("Done"),
                ),
              ]
            : null,
      ),
      body: FocusScope(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TextField(
                controller: searchController,
                focusNode: searchNode,
                style: context.theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                    hintText: "Search for a chat...",
                    hintStyle: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.outline),
                    prefixIcon: Icon(
                      Icons.search,
                      color: context.theme.colorScheme.outline,
                    ),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    filled: false),
              ),
            ),
            if (widget.multiSelect)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: Row(
                  children: [
                    for (final entry in {
                      ChatSelectorFilter.all: "All",
                      ChatSelectorFilter.selected: "Selected",
                      ChatSelectorFilter.unselected: "Unselected",
                    }.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: BBChip(
                          label: Text(
                            entry.value,
                            style: TextStyle(
                              color: selectionFilter == entry.key ? context.theme.colorScheme.primary : null,
                              fontWeight: selectionFilter == entry.key ? FontWeight.bold : null,
                            ),
                          ),
                          selected: selectionFilter == entry.key,
                          showCheckmark: false,
                          onPressed: () => setState(() => selectionFilter = entry.key),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: Obx(() {
                final displayedChats = widget.multiSelect
                    ? filteredChats.where((c) {
                        final isSelected = selectedGuids.contains(c.guid);
                        switch (selectionFilter) {
                          case ChatSelectorFilter.selected:
                            return isSelected;
                          case ChatSelectorFilter.unselected:
                            return !isSelected;
                          case ChatSelectorFilter.all:
                            return true;
                        }
                      }).toList()
                    : filteredChats;
                return Align(
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: CustomScrollView(
                          shrinkWrap: true,
                          physics: ThemeSwitcher.getScrollPhysics(),
                          slivers: <Widget>[
                            SliverList(
                              delegate: SliverChildBuilderDelegate((context, index) {
                                if (displayedChats.isEmpty) {
                                  if (!ChatsSvc.loadedAllChats.isCompleted) {
                                    return Column(
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
                                    );
                                  }
                                  if (filteredChats.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      "No chats match this filter",
                                      style: context.theme.textTheme.labelLarge,
                                    ),
                                  );
                                }
                                final chat = displayedChats[index];
                                final chatState = ChatsSvc.getChatState(chat.guid);
                                final _title = chatState?.title.value ?? chat.getTitle();
                                final selected = selectedGuids.contains(chat.guid);
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      if (widget.multiSelect) {
                                        setState(() {
                                          if (selected) {
                                            selectedGuids.remove(chat.guid);
                                          } else {
                                            selectedGuids.add(chat.guid);
                                          }
                                        });
                                      } else {
                                        widget.onSelect!(chat);
                                        Navigator.of(context).pop();
                                      }
                                    },
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: ChatCreatorTile(
                                            key: ValueKey(chat.guid),
                                            title: _title,
                                            subtitle:
                                                chatState?.chatCreatorSubtitle.value ?? chat.getChatCreatorSubtitle(),
                                            chat: chat,
                                            showTrailing: false,
                                          ),
                                        ),
                                        if (widget.multiSelect)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 16),
                                            child: Icon(
                                              selected ? Icons.check_circle : Icons.circle_outlined,
                                              color: selected
                                                  ? context.theme.colorScheme.primary
                                                  : context.theme.colorScheme.outline,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                                  childCount: displayedChats.isEmpty ? 1 : displayedChats.length),
                            )
                          ],
                        )));
              }),
            ),
          ],
        ),
      ),
    );
  }
}
