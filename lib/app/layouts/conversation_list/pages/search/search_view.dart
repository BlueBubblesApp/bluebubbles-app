import 'package:bluebubbles/app/components/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/app/layouts/chat_selector_view/chat_selector_view.dart';
import 'package:bluebubbles/app/layouts/handle_selector_view/handle_selector_view.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_view/pages/conversation_view.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';
import 'package:sliding_up_panel2/sliding_up_panel2.dart';
import 'package:tuple/tuple.dart';
import 'package:objectbox/src/native/query/query.dart' as obx;

class SearchResult {
  final String search;
  final String chatGuidFilter;
  final String method;
  final List<Tuple2<Chat, Message>> results;

  SearchResult({
    required this.search,
    required this.method,
    required this.results,
    this.chatGuidFilter = "",
  });
}

class SearchView extends StatefulWidget {
  SearchView({
    super.key,
  });

  @override
  SearchViewState createState() => SearchViewState();
}

class SearchViewState extends OptimizedState<SearchView> {
  final Duration animationDuration = const Duration(milliseconds: 400);
  final TextEditingController textEditingController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final PanelController panelController = PanelController();
  final FocusNode focusNode = FocusNode();
  final ConversationListController fakeController =
      Get.put(ConversationListController(showArchivedChats: false, showUnknownSenders: false), tag: "search-view");
  final List<SearchResult> pastSearches = [];

  SearchResult? currentSearch;
  bool noResults = false;
  bool isSearching = false;
  String? currentSearchTerm;
  bool local = false;
  bool network = true;
  Chat? selectedChat;
  Handle? selectedHandle;
  bool isFromMe = false;
  bool showFilters = false;

  Color get backgroundColor => ss.settings.windowEffect.value == WindowEffect.disabled
      ? context.theme.colorScheme.background
      : Colors.transparent;

  @override
  void initState() {
    super.initState();

    // When the user types again after no results, reset no results
    textEditingController.addListener(() {
      if (textEditingController.text != currentSearchTerm && noResults) {
        noResults = false;
      }
    });
  }

  Future<void> search(String newSearch) async {
    if (isSearching || isNullOrEmpty(newSearch)! || newSearch.length < 3) return;
    focusNode.unfocus();
    noResults = false;
    currentSearchTerm = newSearch;

    // If we've already searched for the results and there are none, set no results and return
    if (pastSearches
            .firstWhereOrNull((e) => e.search == newSearch && e.method == (local ? "local" : "network"))
            ?.results
            .isEmpty ??
        false) {
      return setState(() {
        noResults = true;
      });
    }

    setState(() {
      isSearching = true;
    });

    final search = SearchResult(
      search: currentSearchTerm!,
      method: local ? "local" : "network",
      results: [],
    );

    if (local) {
      obx.Condition<Message> condition = Message_.text
          .contains(currentSearchTerm!, caseSensitive: false)
          .and(Message_.associatedMessageGuid.isNull())
          .and(Message_.dateDeleted.isNull())
          .and(Message_.dateCreated.notNull());

      if (isFromMe) {
        condition.and(Message_.isFromMe.equals(true));
      } else if (selectedHandle != null) {
        condition.and(Message_.handleId.equals(selectedHandle!.id!));
      }

      QueryBuilder<Message> qBuilder = messageBox.query(condition);

      if (selectedChat != null) {
        qBuilder = qBuilder..link(Message_.chat, Chat_.guid.equals(selectedChat!.guid));
      }

      final query = qBuilder.order(Message_.dateCreated, flags: Order.descending).build();
      query.limit = 50;
      final results = query.find();
      query.close();

      List<Chat> chats = [];
      List<Message> messages = [];
      messages = results.map((e) {
        // grab attachments, associated messages, and handle
        e.realAttachments;
        e.fetchAssociatedMessages();
        e.handle = e.getHandle();
        return e;
      }).toList();
      chats = results.map((e) => e.chat.target!).toList();
      chats.forEachIndexed((index, element) {
        element.latestMessage = messages[index];
        search.results.add(Tuple2(element, messages[index]));
      });
    } else {
      final whereClause = [
        {
          'statement': 'message.text LIKE :term',
          'args': {'term': "%$currentSearchTerm%"}
        },
        {'statement': 'message.associated_message_guid IS NULL', 'args': null}
      ];

      if (selectedChat != null) {
        whereClause.add({
          'statement': 'chat.guid = :guid',
          'args': {'guid': selectedChat!.guid}
        });
      }

      if (isFromMe) {
        whereClause.add({
          'statement': 'message.is_from_me = :isFromMe',
          'args': {'isFromMe': 1}
        });
      } else if (selectedHandle != null) {
        whereClause.add({
          'statement': 'handle.id = :addr',
          'args': {'addr': selectedHandle!.address}
        });
      }

      final results = await MessagesService.getMessages(
        limit: 50,
        withChats: true,
        withHandles: true,
        withAttachments: true,
        withChatParticipants: true,
        where: whereClause,
      );
      // we query chats from DB so we can get contact names
      // ignore: prefer_const_constructors
      final items = Tuple2(<Chat>[], <Message>[]);
      for (dynamic item in results) {
        final chat = Chat.fromMap(item['chats'][0]);
        final message = Message.fromMap(item);
        items.item1.add(chat);
        items.item2.add(message);
      }
      final chatsToGet = items.item1.map((e) => e.guid).toList();
      final dbChats = chatBox.query(Chat_.guid.oneOf(chatsToGet)).build().find();
      for (int i = 0; i < items.item1.length; i++) {
        final chat = dbChats.firstWhereOrNull((e) => e.guid == items.item1[i].guid) ?? items.item1[i];
        chat.latestMessage = items.item2[i];
        search.results.add(Tuple2(chat, items.item2[i]));
      }
    }

    pastSearches.add(search);
    setState(() {
      isSearching = false;
      noResults = search.results.isEmpty;
      currentSearch = search;
    });
  }

  @override
  Widget build(BuildContext context) {
    int filterCount = 0;
    if (selectedChat != null) filterCount++;
    if (selectedHandle != null) filterCount++;
    if (isFromMe) filterCount++;

    return Stack(children: [
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
                      ss.settings.skin.value == Skins.iOS ? CupertinoIcons.info : Icons.info_outline,
                      size: 20,
                      color: context.theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(
                      "Enter at least 3 characters to begin a search",
                      style:
                          context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface),
                    )),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 15, right: 15, top: 5),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Flexible(
                      child: CupertinoTextField(
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      search(textEditingController.text);
                    },
                    focusNode: focusNode,
                    padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10),
                    controller: textEditingController,
                    placeholder: "Enter a search term...",
                    style: context.theme.textTheme.bodyLarge,
                    placeholderStyle:
                        context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.outline),
                    cursorColor: context.theme.colorScheme.primary,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.theme.colorScheme.primary),
                    ),
                    maxLines: 1,
                    prefix: Padding(
                      padding: const EdgeInsets.only(left: 15),
                      child: Icon(ss.settings.skin.value == Skins.iOS ? CupertinoIcons.search : Icons.search,
                          color: context.theme.colorScheme.outline),
                    ),
                    suffix: Padding(
                      padding: const EdgeInsets.only(right: 15),
                      child: !isSearching
                          ? InkWell(
                              child: Icon(Icons.arrow_forward, color: context.theme.colorScheme.primary),
                              onTap: () {
                                search(textEditingController.text);
                              })
                          : Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: ss.settings.skin.value == Skins.iOS
                                  ? Theme(
                                      data: ThemeData(
                                        cupertinoOverrideTheme: CupertinoThemeData(
                                            brightness: ThemeData.estimateBrightnessForColor(
                                                context.theme.colorScheme.background)),
                                      ),
                                      child: const CupertinoActivityIndicator(),
                                    )
                                  : Container(
                                      height: 20,
                                      width: 20,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                                        ),
                                      ),
                                    ),
                            ),
                    ),
                    suffixMode: OverlayVisibilityMode.editing,
                  )),
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
                        Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();

                                if (showFilters) {
                                  panelController.close();
                                } else {
                                  panelController.open();
                                }
                              },
                              child: Icon(
                                Icons.tune,
                                color: context.theme.colorScheme.primary,
                              ),
                            ))
                      ]))
                ]),
              ),
              if (!kIsWeb)
                Padding(
                  padding: const EdgeInsets.only(left: 15, right: 15, top: 15, bottom: 10),
                  child: ToggleButtons(
                    constraints: BoxConstraints(minWidth: (ns.width(context) - 35) / 2),
                    fillColor: context.theme.colorScheme.primary.withOpacity(0.2),
                    splashColor: context.theme.colorScheme.primary.withOpacity(0.2),
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
                    borderRadius: BorderRadius.circular(20),
                    selectedBorderColor: context.theme.colorScheme.primary,
                    selectedColor: context.theme.colorScheme.primary,
                    borderColor: context.theme.colorScheme.primary.withOpacity(0.5),
                    isSelected: [local, network],
                    onPressed: (index) {
                      if (index == 0) {
                        setState(() {
                          local = true;
                          network = false;
                        });
                      } else {
                        setState(() {
                          local = false;
                          network = true;
                        });
                      }
                      setState(() {
                        isSearching = false;
                        noResults = false;
                        currentSearch = null;
                      });
                    },
                  ),
                ),
              Divider(color: context.theme.colorScheme.outline.withOpacity(0.75)),
              if (!isSearching && noResults)
                Padding(
                    padding: const EdgeInsets.only(top: 25.0),
                    child: Center(child: Text("No results found!", style: context.theme.textTheme.bodyLarge))),
            ]),
          ),
          if (!isSearching && currentSearch != null)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  TextStyle subtitleStyle = context.theme.textTheme.bodySmall!
                      .copyWith(color: context.theme.colorScheme.outline, height: 1.5)
                      .apply(fontSizeFactor: ss.settings.skin.value == Skins.Material ? 1.05 : 1.0);

                  final chat = currentSearch!.results[index].item1;
                  final message = currentSearch!.results[index].item2;

                  // Create the textspans
                  List<InlineSpan> spans = [];

                  // Get the current position of the search term
                  int termStart = message.fullText.toLowerCase().indexOf(currentSearchTerm!.toLowerCase());
                  int termEnd = termStart + currentSearchTerm!.length;

                  if (termStart >= 0) {
                    // We only want a snippet of the text, so only get a 50x50 range
                    // of characters from the string, with the search term in the middle
                    String subText = message.fullText.substring(
                      (termStart - 50).clamp(0, double.infinity).toInt(),
                      (termEnd + 50).clamp(0, message.fullText.length),
                    );

                    // Recalculate the term position in the snippet
                    termStart = subText.toLowerCase().indexOf(currentSearchTerm!.toLowerCase());
                    termEnd = termStart + currentSearchTerm!.length;

                    // Add the beginning string
                    spans.add(TextSpan(text: subText.substring(0, termStart).trimLeft(), style: subtitleStyle));

                    // Add the search term (bolded with color)
                    spans.add(
                      TextSpan(
                          text: subText.substring(termStart, termEnd),
                          style: subtitleStyle.apply(color: context.theme.colorScheme.primary, fontWeightDelta: 2)),
                    );

                    // Add the ending string
                    spans.add(
                        TextSpan(text: subText.substring(termEnd, subText.length).trimRight(), style: subtitleStyle));
                  } else {
                    spans.add(TextSpan(text: message.text, style: subtitleStyle));
                  }

                  return Container(
                    decoration: BoxDecoration(
                      border: !ss.settings.hideDividers.value
                          ? Border(
                              bottom: BorderSide(
                                color: context.theme.colorScheme.background.oppositeLightenOrDarken(15),
                                width: 0.5,
                              ),
                            )
                          : null,
                    ),
                    child: ListTile(
                      mouseCursor: SystemMouseCursors.click,
                      title: RichText(
                        text: TextSpan(
                          children: MessageHelper.buildEmojiText(
                            chat.getTitle(),
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
                        maxLines: ss.settings.denseChatTiles.value
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
                        final service = ms(chat.guid);
                        service.method = local ? "local" : "network";
                        service.struct.addMessages([message]);
                        ns.pushAndRemoveUntil(
                          context,
                          ConversationView(
                            chat: chat,
                            customService: service,
                          ),
                          (route) => route.isFirst,
                        );
                      },
                    ),
                  );
                },
                childCount: currentSearch!.results.length,
              ),
            )
        ],
      ),
      SlidingUpPanel(
        controller: panelController,
        defaultPanelState: PanelState.CLOSED,
        backdropEnabled: true,
        backdropTapClosesPanel: true,
        backdropColor: context.theme.colorScheme.properSurface,
        color: backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        isDraggable: false,
        parallaxEnabled: true,
        minHeight: 0,
        maxHeight: 200,
        panelBuilder: () {
          return Container(
            padding: const EdgeInsets.only(left: 10, right: 10, bottom: 20, top: 20),
            child: Column(children: [
              Center(
                  child: Text(
                "Search Filters",
                style: context.theme.textTheme.headlineSmall,
              )),
              Material(
                  child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        direction: Axis.horizontal,
                        alignment: WrapAlignment.start,
                        spacing: 10,
                        children: [
                          RawChip(
                            tapEnabled: true,
                            deleteIcon: const Icon(Icons.close, size: 16),
                            side: BorderSide(color: context.theme.colorScheme.outline.withOpacity(0.1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                            label: selectedChat != null
                                ? Text(selectedChat!.getTitle(),
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
                            onDeleted: selectedChat == null
                                ? null
                                : () {
                                    setState(() {
                                      selectedChat = null;
                                      isSearching = false;
                                      noResults = false;
                                      currentSearch = null;
                                    });
                                  },
                            onPressed: () {
                              // Push a route that allows the user to select a chat
                              ns.push(context, ChatSelectorView(
                                onSelect: (chat) {
                                  setState(() {
                                    selectedChat = chat;
                                    isSearching = false;
                                    noResults = false;
                                    currentSearch = null;
                                  });
                                },
                              ));
                            },
                          ),
                          if (!isFromMe)
                            RawChip(
                              tapEnabled: true,
                              deleteIcon: const Icon(Icons.close, size: 16),
                              side: BorderSide(color: context.theme.colorScheme.outline.withOpacity(0.1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              avatar: CircleAvatar(
                                backgroundColor: context.theme.colorScheme.primaryContainer,
                                child: Padding(
                                    padding: const EdgeInsets.only(left: 1),
                                    child: Icon(
                                      Icons.person_2_outlined,
                                      color: context.theme.colorScheme.primary,
                                      size: 12,
                                    )),
                              ),
                              label: selectedHandle != null
                                  ? Text(selectedHandle!.displayName,
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
                              onDeleted: selectedHandle == null
                                  ? null
                                  : () {
                                      setState(() {
                                        selectedHandle = null;
                                        isSearching = false;
                                        noResults = false;
                                        currentSearch = null;
                                      });
                                    },
                              onPressed: () {
                                // Push a route that allows the user to select a chat
                                ns.push(context, HandleSelectorView(
                                  onSelect: (handle) {
                                    setState(() {
                                      selectedHandle = handle;
                                      isSearching = false;
                                      noResults = false;
                                      currentSearch = null;
                                    });
                                  },
                                ));
                              },
                            ),
                          if (selectedHandle == null)
                            RawChip(
                              tapEnabled: true,
                              showCheckmark: true,
                              selected: isFromMe,
                              checkmarkColor: context.theme.colorScheme.primary,
                              side: BorderSide(color: context.theme.colorScheme.outline.withOpacity(0.1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              label: Text('Is From You',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.normal,
                                      color: context.theme.colorScheme.onSurface)),
                              onSelected: (selected) {
                                setState(() {
                                  isFromMe = selected;
                                  isSearching = false;
                                  noResults = false;
                                  currentSearch = null;
                                });
                              },
                            )
                        ],
                      ))),
            ]),
          );
        },
      )
    ]);
  }
}
