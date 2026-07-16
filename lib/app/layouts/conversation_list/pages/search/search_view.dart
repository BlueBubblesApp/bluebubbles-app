import 'package:bluebubbles/app/components/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/app/components/bb_chip.dart';
import 'package:bluebubbles/app/layouts/chat_selector_view/chat_selector_view.dart';
import 'package:bluebubbles/app/layouts/conversation_details/dialogs/timeframe_picker.dart';
import 'package:bluebubbles/app/layouts/handle_selector_view/handle_selector_view.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/pages/conversation_view.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';
import 'package:flutter_sliding_up_panel/flutter_sliding_up_panel.dart';

import 'search_models.dart';
import 'search_query_helper.dart';
import 'conversation_search_field.dart';

class SearchResult {
  final String search;
  final String chatGuidFilter;
  final SearchMode mode;
  final List<SearchResultItem> results;

  SearchResult({
    required this.search,
    required this.mode,
    required this.results,
    this.chatGuidFilter = "",
  });
}

class SearchView extends StatefulWidget {
  const SearchView({
    super.key,
  });

  @override
  SearchViewState createState() => SearchViewState();
}

class SearchViewState extends State<SearchView> with ThemeHelpers {
  final TextEditingController textEditingController = TextEditingController();
  final SlidingUpPanelController panelController = SlidingUpPanelController();
  final FocusNode focusNode = FocusNode();
  final List<SearchResult> pastSearches = [];

  final Rx<SearchResult?> currentSearch = Rx<SearchResult?>(null);
  final RxBool noResults = false.obs;
  final RxBool isSearching = false.obs;
  final Rx<String?> currentSearchTerm = Rx<String?>(null);
  final RxBool local = false.obs;
  final RxBool network = true.obs;
  final Rx<Chat?> selectedChat = Rx<Chat?>(null);
  final Rx<Handle?> selectedHandle = Rx<Handle?>(null);
  final RxBool isFromMe = false.obs;
  final RxBool isNotFromMe = false.obs;
  final Rx<DateTime?> sinceDate = Rx<DateTime?>(null);

  Color get backgroundColor => SettingsSvc.settings.windowEffect.value == WindowEffect.disabled
      ? context.theme.colorScheme.surface
      : Colors.transparent;

  @override
  void initState() {
    super.initState();

    // When the user types again after no results, reset no results
    textEditingController.addListener(() {
      if (textEditingController.text != currentSearchTerm.value && noResults.value) {
        noResults.value = false;
      }
    });
  }

  Future<void> search(String newSearch) async {
    if (isSearching.value || isNullOrEmpty(newSearch) || newSearch.length < 3) return;
    focusNode.unfocus();
    noResults.value = false;
    currentSearchTerm.value = newSearch;

    // If we've already searched for the results and there are none, set no results and return
    if (pastSearches
            .firstWhereOrNull(
              (e) => e.search == newSearch && e.mode == (local.value ? SearchMode.local : SearchMode.network),
            )
            ?.results
            .isEmpty ??
        false) {
      noResults.value = true;
      return;
    }

    isSearching.value = true;

    final search = SearchResult(
      search: currentSearchTerm.value!,
      mode: local.value ? SearchMode.local : SearchMode.network,
      results: [],
    );

    if (local.value) {
      search.results.addAll(
        await SearchQueryHelper.runLocal(
          term: currentSearchTerm.value!,
          selectedChat: selectedChat.value,
          selectedHandle: selectedHandle.value,
          isFromMe: isFromMe.value,
          isNotFromMe: isNotFromMe.value,
          sinceDate: sinceDate.value,
        ),
      );
    } else {
      search.results.addAll(
        await SearchQueryHelper.runNetwork(
          term: currentSearchTerm.value!,
          selectedChat: selectedChat.value,
          selectedHandle: selectedHandle.value,
          isFromMe: isFromMe.value,
          isNotFromMe: isNotFromMe.value,
          sinceDate: sinceDate.value,
        ),
      );
    }

    pastSearches.add(search);
    isSearching.value = false;
    noResults.value = search.results.isEmpty;
    currentSearch.value = search;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      int filterCount = 0;
      if (selectedChat.value != null) filterCount++;
      if (selectedHandle.value != null) filterCount++;
      if (isFromMe.value) filterCount++;
      if (isNotFromMe.value) filterCount++;
      if (sinceDate.value != null) filterCount++;

      bool showSenderFilter = !isNotFromMe.value && !isFromMe.value && (selectedChat.value?.isGroup ?? true);

      return PopScope(
          canPop: false,
          onPopInvokedWithResult: <T>(bool didPop, T? result) {
            if (didPop) return;
            if (panelController.status != SlidingUpPanelStatus.collapsed) {
              panelController.collapse();
            } else {
              final NavigatorState navigator = Navigator.of(context);
              navigator.pop();
            }
          },
          child: Stack(children: [
            SettingsScaffold(
              title: "Search",
              initialHeader: null,
              iosSubtitle: iosSubtitle,
              materialSubtitle: materialSubtitle,
              tileColor: backgroundColor,
              headerColor: backgroundColor,
              bodySlivers: [
                SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            SettingsSvc.settings.skin.value == Skins.iOS ? CupertinoIcons.info : Icons.info_outline,
                            size: 20,
                            color: context.theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(
                            "Enter at least 3 characters to begin a search",
                            style: context.theme.textTheme.bodySmall!
                                .copyWith(color: context.theme.colorScheme.onSurfaceVariant),
                          )),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 15, right: 15, top: 5),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Flexible(
                          child: ConversationSearchField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            isSearching: isSearching.value,
                            onSubmitted: search,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        Container(
                            margin: const EdgeInsets.only(left: 10),
                            width: 35,
                            height: 40,
                            child: Stack(children: [
                              if (filterCount > 0)
                                Positioned(
                                  top: -4,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: context.theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      filterCount.toString(),
                                      style: context.theme.textTheme.bodySmall!
                                          .copyWith(color: context.theme.colorScheme.onPrimary),
                                    ),
                                  ),
                                ),
                              Container(
                                  margin: const EdgeInsets.only(left: 5),
                                  child: Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: InkWell(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          if (focusNode.hasFocus) {
                                            focusNode.unfocus();
                                          }

                                          if (panelController.status != SlidingUpPanelStatus.expanded) {
                                            panelController.expand();
                                          }
                                        },
                                        child: Icon(
                                          Icons.tune,
                                          color: context.theme.colorScheme.primary,
                                        ),
                                      )))
                            ]))
                      ]),
                    ),
                    if (!kIsWeb)
                      Obx(() {
                        NavigationSvc.listener.value;
                        return Padding(
                          padding: const EdgeInsets.only(left: 15, right: 15, top: 15, bottom: 10),
                          child: ToggleButtons(
                            constraints: BoxConstraints(minWidth: (NavigationSvc.width(context) * 0.9) / 2),
                            fillColor: context.theme.colorScheme.primary.withValues(alpha: 0.2),
                            splashColor: context.theme.colorScheme.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            selectedBorderColor: context.theme.colorScheme.primary,
                            selectedColor: context.theme.colorScheme.primary,
                            borderColor: context.theme.colorScheme.primary.withValues(alpha: 0.5),
                            isSelected: [local.value, network.value],
                            onPressed: (index) {
                              if (index == 0) {
                                local.value = true;
                                network.value = false;
                              } else {
                                local.value = false;
                                network.value = true;
                              }
                              isSearching.value = false;
                              noResults.value = false;
                              currentSearch.value = null;
                            },
                            children: [
                              const Row(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text("Search Device"),
                                  ),
                                  Icon(Icons.storage_outlined, size: 16),
                                ],
                              ),
                              const Row(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text("Search Mac"),
                                  ),
                                  Icon(Icons.cloud_outlined, size: 16),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    Divider(color: context.theme.colorScheme.outline.withValues(alpha: 0.75)),
                    if (!isSearching.value && noResults.value)
                      Padding(
                          padding: const EdgeInsets.only(top: 25.0),
                          child: Center(child: Text("No results found!", style: context.theme.textTheme.bodyLarge))),
                  ]),
                ),
                if (!isSearching.value && currentSearch.value != null)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        TextStyle subtitleStyle = context.theme.textTheme.bodySmall!
                            .copyWith(color: context.theme.colorScheme.outline, height: 1.5)
                            .apply(fontSizeFactor: SettingsSvc.settings.skin.value == Skins.Material ? 1.05 : 1.0);

                        final chat = currentSearch.value!.results[index].chat;
                        final message = currentSearch.value!.results[index].message;

                        // Create the textspans
                        List<InlineSpan> spans = [];

                        // Get the current position of the search term
                        int termStart = message.fullText.toLowerCase().indexOf(currentSearchTerm.value!.toLowerCase());
                        int termEnd = termStart + currentSearchTerm.value!.length;

                        if (termStart >= 0) {
                          // We only want a snippet of the text, so only get a 50x50 range
                          // of characters from the string, with the search term in the middle
                          String subText = message.fullText.substring(
                            (termStart - 50).clamp(0, double.infinity).toInt(),
                            (termEnd + 50).clamp(0, message.fullText.length),
                          );

                          // Recalculate the term position in the snippet
                          termStart = subText.toLowerCase().indexOf(currentSearchTerm.value!.toLowerCase());
                          termEnd = termStart + currentSearchTerm.value!.length;

                          // Add the beginning string
                          spans.add(TextSpan(text: subText.substring(0, termStart).trimLeft(), style: subtitleStyle));

                          // Add the search term (bolded with color)
                          spans.add(
                            TextSpan(
                                text: subText.substring(termStart, termEnd),
                                style:
                                    subtitleStyle.apply(color: context.theme.colorScheme.primary, fontWeightDelta: 2)),
                          );

                          // Add the ending string
                          spans.add(TextSpan(
                              text: subText.substring(termEnd, subText.length).trimRight(), style: subtitleStyle));
                        } else {
                          spans.add(TextSpan(text: message.text, style: subtitleStyle));
                        }

                        return Container(
                          decoration: BoxDecoration(
                            border: !SettingsSvc.settings.hideDividers.value
                                ? Border(
                                    bottom: BorderSide(
                                      color: context.theme.colorScheme.surface.oppositeLightenOrDarken(15),
                                      width: 0.5,
                                    ),
                                  )
                                : null,
                          ),
                          child: ListTile(
                            mouseCursor: MouseCursor.defer,
                            title: RichText(
                              text: TextSpan(
                                children: MessageHelper.buildEmojiText(
                                  ChatsSvc.getChatState(chat.guid)?.title.value ?? chat.getTitle(),
                                  context.theme.textTheme.bodyLarge!,
                                ),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: RichText(
                              text: TextSpan(
                                children: spans,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: SettingsSvc.settings.denseChatTiles.value
                                  ? 1
                                  : material
                                      ? 3
                                      : 2,
                            ),
                            leading: ContactAvatarGroupWidget(
                              chat: chat,
                              size: 40,
                              editable: false,
                            ),
                            trailing: Text(
                              buildDate(message.dateCreated),
                              textAlign: TextAlign.right,
                              style: context.theme.textTheme.bodySmall,
                              overflow: TextOverflow.clip,
                            ),
                            onTap: () {
                              final service = maybeFindMessagesSvc(chat.guid) ?? MessagesService(chat.guid);
                              service.method = local.value ? SearchMode.local.name : SearchMode.network.name;
                              service.struct.addMessages([message]);
                              NavigationSvc.pushAndRemoveUntil(
                                context,
                                ConversationView(
                                  chat: chat,
                                  customService: service,
                                  initialScrollToGuid: message.guid,
                                ),
                                (route) => route.isFirst,
                              );
                            },
                          ),
                        );
                      },
                      childCount: currentSearch.value!.results.length,
                    ),
                  )
              ],
            ),
            SlidingUpPanelWidget(
              panelController: panelController,
              anchor: 1,
              controlHeight: 0,
              enableOnTap: false,
              child: Column(children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (a_) {
                      if (panelController.status != SlidingUpPanelStatus.collapsed) {
                        panelController.collapse();
                      }
                    },
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    color: tileColor,
                  ),
                  height: 255,
                  padding: const EdgeInsets.only(left: 10, right: 10, bottom: 20, top: 20),
                  child: Column(children: [
                    Center(
                        child: Text(
                      "Search Filters",
                      style: context.theme.textTheme.headlineSmall,
                    )),
                    Material(
                        color: Colors.transparent,
                        child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Wrap(
                              direction: Axis.horizontal,
                              alignment: WrapAlignment.start,
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                BBChip(
                                  avatar: CircleAvatar(
                                    backgroundColor: context.theme.colorScheme.primaryContainer,
                                    child: Icon(
                                      Icons.calendar_today_outlined,
                                      color: context.theme.colorScheme.primary,
                                      size: 12,
                                    ),
                                  ),
                                  label: sinceDate.value != null
                                      ? Text(
                                          "Since ${buildFullDate(sinceDate.value!, includeTime: sinceDate.value!.isToday(), useTodayYesterday: true)}",
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.normal,
                                              color: context.theme.colorScheme.onSurface),
                                          overflow: TextOverflow.ellipsis)
                                      : Text('Filter by Date',
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.normal,
                                              color: context.theme.colorScheme.onSurface)),
                                  onDeleted: sinceDate.value == null
                                      ? null
                                      : () {
                                          sinceDate.value = null;
                                          isSearching.value = false;
                                          noResults.value = false;
                                          currentSearch.value = null;
                                        },
                                  onPressed: () async {
                                    sinceDate.value = await showTimeframePicker("Since When?", context,
                                        customTimeframes: {
                                          "1 Hour": 1,
                                          "1 Day": 24,
                                          "1 Week": 168,
                                          "1 Month": 720,
                                          "6 Months": 4320,
                                          "1 Year": 8760,
                                        },
                                        selectionSuffix: "Ago",
                                        useTodayYesterday: true);
                                    isSearching.value = false;
                                    noResults.value = false;
                                    currentSearch.value = null;
                                  },
                                ),
                                BBChip(
                                  avatar: CircleAvatar(
                                    backgroundColor: context.theme.colorScheme.primaryContainer,
                                    child: Padding(
                                        padding: const EdgeInsets.only(left: 1, top: 1),
                                        child: Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          color: context.theme.colorScheme.primary,
                                          size: 12,
                                        )),
                                  ),
                                  label: selectedChat.value != null
                                      ? Text(
                                          ChatsSvc.getChatState(selectedChat.value!.guid)?.title.value ??
                                              selectedChat.value!.getTitle(),
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.normal,
                                              color: context.theme.colorScheme.onSurface),
                                          overflow: TextOverflow.ellipsis)
                                      : Text('Filter by Chat',
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.normal,
                                              color: context.theme.colorScheme.onSurface)),
                                  onDeleted: selectedChat.value == null
                                      ? null
                                      : () {
                                          selectedChat.value = null;
                                          isSearching.value = false;
                                          noResults.value = false;
                                          currentSearch.value = null;
                                        },
                                  onPressed: () {
                                    // Push a route that allows the user to select a chat
                                    NavigationSvc.push(context, ChatSelectorView(
                                      onSelect: (chat) {
                                        selectedChat.value = chat;
                                        isSearching.value = false;
                                        noResults.value = false;
                                        currentSearch.value = null;
                                      },
                                    ));
                                  },
                                ),
                                if (showSenderFilter)
                                  BBChip(
                                    avatar: CircleAvatar(
                                      backgroundColor: context.theme.colorScheme.primaryContainer,
                                      child: Icon(
                                        Icons.person_2_outlined,
                                        color: context.theme.colorScheme.primary,
                                        size: 12,
                                      ),
                                    ),
                                    label: selectedHandle.value != null
                                        ? Text(selectedHandle.value!.displayName,
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.normal,
                                                color: context.theme.colorScheme.onSurface),
                                            overflow: TextOverflow.ellipsis)
                                        : Text('Filter by Sender',
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.normal,
                                                color: context.theme.colorScheme.onSurface)),
                                    onDeleted: selectedHandle.value == null
                                        ? null
                                        : () {
                                            selectedHandle.value = null;
                                            isSearching.value = false;
                                            noResults.value = false;
                                            currentSearch.value = null;
                                          },
                                    onPressed: () {
                                      // Push a route that allows the user to select a chat
                                      NavigationSvc.push(
                                          context,
                                          HandleSelectorView(
                                            forChat: selectedChat.value,
                                            onSelect: (handle) {
                                              selectedHandle.value = handle;
                                              isSearching.value = false;
                                              noResults.value = false;
                                              currentSearch.value = null;
                                            },
                                          ));
                                    },
                                  ),
                                if (selectedHandle.value == null && !isNotFromMe.value)
                                  BBChip(
                                    showCheckmark: true,
                                    selected: isFromMe.value,
                                    checkmarkColor: context.theme.colorScheme.primary,
                                    label: Text('From You',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.normal,
                                            color: context.theme.colorScheme.onSurface)),
                                    onSelected: (selected) {
                                      isFromMe.value = selected;
                                      isSearching.value = false;
                                      noResults.value = false;
                                      currentSearch.value = null;
                                    },
                                  ),
                                if (selectedHandle.value == null && !isFromMe.value)
                                  BBChip(
                                    showCheckmark: true,
                                    selected: isNotFromMe.value,
                                    checkmarkColor: context.theme.colorScheme.primary,
                                    label: Text('Not From You',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.normal,
                                            color: context.theme.colorScheme.onSurface)),
                                    onSelected: (selected) {
                                      isNotFromMe.value = selected;
                                      isSearching.value = false;
                                      noResults.value = false;
                                      currentSearch.value = null;
                                    },
                                  ),
                              ],
                            ))),
                  ]),
                )
              ]),
            )
          ]));
    });
  }
}
