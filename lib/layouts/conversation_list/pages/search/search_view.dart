import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/settings/theme_helpers_mixin.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/layouts/stateful_boilerplate.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/message/message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/repository/models/objectbox.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tuple/tuple.dart';

class SearchResult {
  final String search;
  final String method;
  final List<Tuple2<Chat, Message>> results;

  SearchResult({required this.search, required this.method, required this.results});
}

class SearchView extends StatefulWidget {
  SearchView({
    Key? key,
  }) : super(key: key);

  @override
  SearchViewState createState() => SearchViewState();
}

class SearchViewState extends OptimizedState<SearchView> with ThemeHelpers {
  final Duration animationDuration = Duration(milliseconds: 400);
  final TextEditingController textEditingController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final FocusNode focusNode = FocusNode();
  final ConversationListController fakeController = Get.put(
    ConversationListController(
      showArchivedChats: false,
      showUnknownSenders: false
    ),
    tag: "search-view"
  );
  final List<SearchResult> pastSearches = [];

  SearchResult? currentSearch;
  bool noResults = false;
  bool isSearching = false;
  String? currentSearchTerm;
  bool local = false;
  bool network = true;

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
    if (pastSearches.firstWhereOrNull(
            (e) => e.search == newSearch && e.method == (local ? "local" : "network"))?.results.isEmpty ?? false) {
      return setState(() {
        noResults = true;
      });
    }

    setState(() {
      isSearching = true;
    });

    List<dynamic> response = [];
    if (local) {
      final query = (messageBox.query(Message_.text.contains(currentSearchTerm!)
          .and(Message_.associatedMessageGuid.isNull())
          .and(Message_.dateDeleted.isNull()))
        ..order(Message_.dateCreated, flags: Order.descending)).build();
      query.limit = 50;
      final messages = query.find();
      query.close();

      response = messages.map((e) {
        // grab attachments and associated messages
        e.getRealAttachments();
        e.fetchAssociatedMessages();
        final map = e.toMap(includeObjects: true);
        final chat = e.chat.target!;
        // grab participants
        chat.getParticipants();
        map['chats'] = [chat.toMap()];
        return map;
      }).toList();
    } else {
      response = await MessageManager().getMessages(
          limit: 50,
          withChats: true,
          withHandles: true,
          withAttachments: true,
          withChatParticipants: true,
          where: [
            {
              'statement': 'message.text LIKE :term',
              'args': {'term': "%$currentSearchTerm%"}
            },
            {'statement': 'message.associated_message_guid IS NULL', 'args': null}
          ]
      );
    }

    final search = SearchResult(
      search: currentSearchTerm!,
      method: local ? "local" : "network",
      results: [],
    );

    for (dynamic item in response) {
      final chat = Chat.fromMap(item['chats'][0]);
      if (chat.participants.isEmpty) {
        chat.participants = chatBox.query(Chat_.guid.equals(chat.guid)).build().findFirst()?.handles.toList() ?? [];
      }
      final message = Message.fromMap(item);
      chat.latestMessage = message;
      chat.guid = "${chat.guid}/${randomString(6)}";
      search.results.add(Tuple2(chat, message));
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
    return SettingsScaffold(
      title: "Search",
      initialHeader: null,
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      tileColor: tileColor,
      headerColor: headerColor,
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
                    SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.info : Icons.info_outline,
                    size: 20,
                    color: context.theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Enter at least 3 characters to begin a search",
                      style: context.theme.textTheme.bodySmall!
                          .copyWith(color: context.theme.colorScheme.properOnSurface),
                    )
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
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
                placeholderStyle: context.theme.textTheme.bodyLarge!
                    .copyWith(color: context.theme.colorScheme.outline),
                cursorColor: context.theme.colorScheme.primary,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.theme.colorScheme.primary),
                ),
                maxLines: 1,
                prefix: Padding(
                  padding: const EdgeInsets.only(left: 15),
                  child: Icon(
                    SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.search : Icons.search,
                    color: context.theme.colorScheme.outline
                  ),
                ),
                suffix: Padding(
                  padding: const EdgeInsets.only(right: 15),
                  child: !isSearching ? InkWell(
                      child: Icon(Icons.arrow_forward, color: context.theme.colorScheme.primary),
                      onTap: () {
                        search(textEditingController.text);
                      }
                    ) : Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: SettingsManager().settings.skin.value == Skins.iOS
                        ? Theme(
                            data: ThemeData(
                              cupertinoOverrideTheme: CupertinoThemeData(
                                brightness: ThemeData.estimateBrightnessForColor(
                                  context.theme.colorScheme.background)
                              ),
                            ),
                            child: CupertinoActivityIndicator(),
                          ) : Container(
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
              ),
            ),
            if (!kIsWeb)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
                child: ToggleButtons(
                  constraints: BoxConstraints(minWidth: (context.width - 35) / 2),
                  children: [
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text("Search Device"),
                        ),
                        Icon(Icons.storage_outlined, size: 16),
                      ],
                    ),
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text("Search Mac"),
                        ),
                        Icon(Icons.cloud_outlined, size: 16),
                      ],
                    ),
                  ],
                  borderRadius: BorderRadius.circular(20),
                  selectedBorderColor: context.theme.colorScheme.primary,
                  selectedColor: context.theme.colorScheme.primary,
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
                  },
                ),
              ),
            Divider(color: context.theme.colorScheme.outline),
            if (!isSearching && noResults)
              Padding(
                padding: const EdgeInsets.only(top: 25.0),
                child: Center(child: Text("No results found!", style: context.theme.textTheme.bodyLarge))
              ),
          ]),
        ),
        if (!isSearching && currentSearch != null)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                TextStyle subtitleStyle = context.theme.textTheme.bodySmall!
                    .copyWith(color: context.theme.colorScheme.outline, height: 1.5)
                    .apply(fontSizeFactor: SettingsManager().settings.skin.value == Skins.Material ? 1.05 : 1.0);

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
                      style: subtitleStyle.apply(color: context.theme.colorScheme.primary, fontWeightDelta: 2)
                    ),
                  );

                  // Add the ending string
                  spans.add(TextSpan(text: subText.substring(termEnd, subText.length).trimRight(), style: subtitleStyle));
                } else {
                  spans.add(TextSpan(text: message.text, style: subtitleStyle));
                }

                return Container(
                  decoration: BoxDecoration(
                    border: !SettingsManager().settings.hideDividers.value ? Border(
                      bottom: BorderSide(
                        color: context.theme.colorScheme.background.lightenOrDarken(15),
                        width: 0.5,
                      ),
                    ) : null,
                  ),
                  child: ConversationTile(
                    chat: chat,
                    subtitle: RichText(
                      text: TextSpan(children: spans),
                    ),
                    controller: fakeController,
                    inSelectMode: true,
                    onSelect: (_) {
                      MessageBloc customBloc = MessageBloc(chat, canLoadMore: false, loadMethod: local ? "local" : "network");
                      CustomNavigator.push(
                        context,
                        ConversationView(
                          chat: chat,
                          existingAttachments: [],
                          existingText: null,
                          isCreator: false,
                          customMessageBloc: customBloc,
                          onMessagesViewComplete: () {
                            customBloc.loadSearchChunk(message);
                          },
                        ),
                      );
                    },
                  ),
                );
              },
              childCount: currentSearch!.results.length,
            ),
          )
      ],
    );
  }
}
