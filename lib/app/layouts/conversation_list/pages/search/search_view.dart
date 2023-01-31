import 'package:bluebubbles/app/components/avatars/contact_avatar_group_widget.dart';
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
import 'package:flutter_acrylic/flutter_acrylic.dart';
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

class SearchViewState extends OptimizedState<SearchView> {
  final Duration animationDuration = const Duration(milliseconds: 400);
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
    if (pastSearches.firstWhereOrNull(
            (e) => e.search == newSearch && e.method == (local ? "local" : "network"))?.results.isEmpty ?? false) {
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
      final query = (messageBox.query(Message_.text.contains(currentSearchTerm!)
          .and(Message_.associatedMessageGuid.isNull())
          .and(Message_.dateDeleted.isNull())
          .and(Message_.dateCreated.notNull()))
        ..order(Message_.dateCreated, flags: Order.descending)).build();
      query.limit = 50;
      final results = query.find();
      query.close();

      List<Chat> chats = [];
      List<Message> messages = [];
      messages = results.map((e) {
        // grab attachments and associated messages
        e.realAttachments;
        e.fetchAssociatedMessages();
        return e;
      }).toList();
      chats = results.map((e) => e.chat.target!).toList();
      chats.forEachIndexed((index, element) {
        element.latestMessage = messages[index];
        search.results.add(Tuple2(element, messages[index]));
      });
    } else {
      final results = await MessagesService.getMessages(
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
        ],
      );
      // we query chats from DB so we can get contact names
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
    return SettingsScaffold(
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
                    ss.settings.skin.value == Skins.iOS ? CupertinoIcons.search : Icons.search,
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
                      child: ss.settings.skin.value == Skins.iOS
                        ? Theme(
                            data: ThemeData(
                              cupertinoOverrideTheme: CupertinoThemeData(
                                brightness: ThemeData.estimateBrightnessForColor(
                                  context.theme.colorScheme.background)
                              ),
                            ),
                            child: const CupertinoActivityIndicator(),
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
                  constraints: BoxConstraints(minWidth: (ns.width(context) - 35) / 2),
                  fillColor: context.theme.colorScheme.primary.withOpacity(0.2),
                  splashColor: context.theme.colorScheme.primary.withOpacity(0.2),
                  children: [
                    Row(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text("Search Device"),
                        ),
                        const Icon(Icons.storage_outlined, size: 16),
                      ],
                    ),
                    Row(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text("Search Mac"),
                        ),
                        const Icon(Icons.cloud_outlined, size: 16),
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
                    border: !ss.settings.hideDividers.value ? Border(
                      bottom: BorderSide(
                        color: context.theme.colorScheme.background.oppositeLightenOrDarken(15),
                        width: 0.5,
                      ),
                    ) : null,
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
                      maxLines: ss.settings.denseChatTiles.value ? 1 : material ? 3 : 2,
                    ),
                    leading: ContactAvatarGroupWidget(
                      chat: chat,
                      size: 40,
                      editable: false,
                      onTap: () {},
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
    );
  }
}
