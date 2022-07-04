import 'dart:ui';

import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_group_widget.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/message/message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class SearchView extends StatefulWidget {
  SearchView({
    Key? key,
  }) : super(key: key);

  @override
  SearchViewState createState() => SearchViewState();
}

class SearchViewState extends State<SearchView> {
  List<dynamic> results = [];

  GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final Duration animationDuration = Duration(milliseconds: 400);
  final TextEditingController textEditingController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool isSearching = false;
  Map<String, Chat> chatCache = {};
  final FocusNode _focusNode = FocusNode();
  Map<String, int> resultCache = {};
  bool noResults = false;
  String? previousSearch;

  @override
  void initState() {
    super.initState();

    // When the user types again after no results, reset no results
    textEditingController.addListener(() {
      if (textEditingController.text != previousSearch && noResults && mounted) {
        setState(() {
          noResults = false;
        });
      }
    });

    _focusNode.requestFocus();
  }

  Future<void> search(String term) async {
    if (isSearching || isNullOrEmpty(term)! || term.length < 3) return;
    _focusNode.unfocus();
    noResults = false;
    previousSearch = term;

    // If we've already searched for the results and there are none, set no results and return
    if (resultCache.containsKey(term) && resultCache[term] == 0 && mounted) {
      setState(() {
        noResults = true;
      });

      return;
    }

    if (mounted) {
      setState(() {
        isSearching = true;
      });
    }

    List<dynamic> results = await MessageManager().getMessages(limit: 50, withChats: true, withHandles: true, where: [
      {
        'statement': 'message.text LIKE :term',
        'args': {'term': "%${textEditingController.text}%"}
      },
      {'statement': 'message.associated_message_guid IS NULL', 'args': null}
    ]);

    List<dynamic> _results = [];
    for (dynamic item in results) {
      // Build the data map
      Map<String, dynamic> data = {'message': Message.fromMap(item), 'chat': Chat.fromMap(item['chats'][0])};

      // If we've already got this chat, use the cached one
      if (chatCache.containsKey(data['chat'].guid)) {
        data['chat'] = chatCache[data['chat'].guid];
      } else {
        if (kIsWeb) {
          data['chat'] = await Chat.findOneWeb(guid: data['chat'].guid);
        } else {
          data['chat'] = Chat.findOne(guid: data['chat'].guid);
        }

        // Add the chat to the cache
        if (data['chat'] != null) {
          chatCache[data['chat'].guid] = data['chat'];
        }
      }

      // Only add the item if the chat is not null
      if (data['chat'] != null) {
        // Make sure to get the chat title!
        await data['chat'].getTitle();
        data['chat'] = data['chat'].getParticipants();

        // Add the item to the results
        _results.add(data);
      }
    }

    this.results = _results;
    _listKey = GlobalKey<AnimatedListState>();

    // Add the cached result
    resultCache[term] = this.results.length;

    // Update the UI with the results
    if (mounted) {
      setState(() {
        isSearching = false;
        noResults = this.results.isEmpty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Brightness brightness = context.theme.colorScheme.brightness;
    // Samsung theme should always use the background color as the "header" color
    Color headerColor = ThemeManager().inDarkMode(context)
        ? context.theme.colorScheme.background : context.theme.colorScheme.properSurface;
    Color tileColor = ThemeManager().inDarkMode(context)
        ? context.theme.colorScheme.properSurface : context.theme.colorScheme.background;

    // reverse material color mapping to be more accurate
    if (SettingsManager().settings.skin.value == Skins.Material && ThemeManager().inDarkMode(context)) {
      final temp = headerColor;
      headerColor = tileColor;
      tileColor = temp;
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Scaffold(
        // extendBodyBehindAppBar: true,
        backgroundColor: context.theme.colorScheme.background,
        appBar: PreferredSize(
          preferredSize: Size(CustomNavigator.width(context), 50),
          child: ClipRRect(
            child: BackdropFilter(
              child: AppBar(
                systemOverlayStyle:
                brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
                toolbarHeight: 50,
                elevation: 0,
                scrolledUnderElevation: 3,
                surfaceTintColor: context.theme.colorScheme.primary,
                leading: buildBackButton(context),
                backgroundColor: headerColor.withOpacity(0.5),
                title: Text(
                  "Search",
                  style: context.theme.textTheme.titleLarge,
                ),
                centerTitle: SettingsManager().settings.skin.value == Skins.iOS,
              ),
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            ),
          ),
        ),
        body: Column(
          children: [
            Container(padding: EdgeInsets.only(top: 8.0)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    SettingsManager().settings.skin.value == Skins.iOS
                        ? CupertinoIcons.info
                        : Icons.info_outline,
                    size: 20,
                    color: context.theme.colorScheme.primary,
                  ),
                  SizedBox(width: 20),
                  Expanded(
                      child: Text(
                        "Enter at least 3 characters to begin a search",
                        style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface),
                      )
                  ),
                ],
              ),
            ),
            Container(
                padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
                child: CupertinoTextField(
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) {
                    search(textEditingController.text);
                  },
                  focusNode: _focusNode,
                  padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 10),
                  controller: textEditingController,
                  placeholder: "Enter a search term...",
                  style: context.theme.textTheme.bodyLarge,
                  placeholderStyle: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline),
                  cursorColor: context.theme.colorScheme.primary,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.theme.colorScheme.primary)),
                  maxLines: 1,
                  prefix: Padding(
                    padding: EdgeInsets.only(left: 15),
                    child: Icon(SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.search : Icons.search,
                        color: context.theme.colorScheme.outline),
                  ),
                  suffix: Padding(
                    padding: EdgeInsets.only(right: 15),
                    child: (!isSearching)
                        ? InkWell(
                        child: Icon(Icons.arrow_forward,
                            color: context.theme.colorScheme.primary),
                        onTap: () {
                          search(textEditingController.text);
                        })
                        : Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: SettingsManager().settings.skin.value == Skins.iOS
                          ? Theme(
                        data: ThemeData(
                          cupertinoOverrideTheme: CupertinoThemeData(
                              brightness: ThemeData.estimateBrightnessForColor(context.theme.colorScheme.background)),
                        ),
                        child: CupertinoActivityIndicator(),
                      )
                          : Container(
                          height: 20,
                          width: 20,
                          child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                              ))),
                    ),
                  ),
                  suffixMode: OverlayVisibilityMode.editing,
                )),
            Divider(color: context.theme.colorScheme.outline),
            (!isSearching && noResults)
                ? Padding(
                    padding: EdgeInsets.only(top: 25.0),
                    child: Text("No results found!", style: context.theme.textTheme.bodyLarge))
                : (!isSearching)
                    ? Flexible(
                        fit: FlexFit.loose,
                        child: ScrollbarWrapper(
                          controller: _scrollController,
                          child: AnimatedList(
                            key: _listKey,
                            controller: _scrollController,
                            physics: (SettingsManager().settings.betterScrolling.value && (kIsDesktop || kIsWeb))
                                ? NeverScrollableScrollPhysics()
                                : ThemeSwitcher.getScrollPhysics(),
                            initialItemCount: results.length,
                            itemBuilder: (BuildContext context, int index, Animation<double> animation) {
                              TextStyle titleStyle = (SettingsManager().settings.skin.value == Skins.Material ? context.theme.textTheme.bodyMedium : context.theme.textTheme.bodyLarge)!.copyWith(
                                  fontWeight: SettingsManager().settings.skin.value == Skins.iOS
                                      ? FontWeight.w600 : null)
                                  .apply(fontSizeFactor: SettingsManager().settings.skin.value == Skins.Material ? 1.1 : 1.0);

                              TextStyle subtitleStyle = context.theme.textTheme.bodySmall!.copyWith(
                                  color: context.theme.colorScheme.outline,
                                  height: 1.5
                              ).apply(fontSizeFactor: SettingsManager().settings.skin.value == Skins.Material ? 1.05 : 1.0);

                              Message message = results[index]['message'];
                              Chat? chat = results[index]['chat'];

                              // Create the textspans
                              List<InlineSpan> spans = [];

                              // Get the current position of the search term
                              int termIndex =
                                  (message.text ?? "").toLowerCase().indexOf(textEditingController.text.toLowerCase());
                              int termEnd = termIndex + textEditingController.text.length;

                              if (termIndex >= 0) {
                                // We only want a snippet of the text, so only get a 50x50 range
                                // of characters from the string, with the search term in the middle
                                String subText = message.text!.substring((termIndex - 50 >= 0) ? termIndex - 50 : 0,
                                    (termEnd + 50 < message.text!.length) ? termEnd + 50 : message.text!.length);

                                // Recarculate the term position in the snippet
                                termIndex = subText.toLowerCase().indexOf(textEditingController.text.toLowerCase());
                                termEnd = termIndex + textEditingController.text.length;

                                // Add the beginning string
                                spans.add(TextSpan(
                                    text: subText.substring(0, termIndex).trimLeft(),
                                    style: subtitleStyle));

                                // Add the search term
                                spans.add(TextSpan(
                                    text: subText.substring(termIndex, termEnd),
                                    style: subtitleStyle
                                        .apply(color: context.theme.colorScheme.primary, fontWeightDelta: 2)));

                                // Add the ending string
                                spans.add(TextSpan(
                                    text: subText.substring(termEnd, subText.length).trimRight(),
                                    style: subtitleStyle));
                              } else {
                                spans.add(TextSpan(text: message.text, style: subtitleStyle));
                              }

                              return Container(
                                decoration: BoxDecoration(
                                  border: (!SettingsManager().settings.hideDividers.value)
                                      ? Border(
                                    bottom: BorderSide(
                                      color: context.theme.colorScheme.background.lightenOrDarken(15),
                                      width: 0.5,
                                    ),
                                  )
                                      : null,
                                ),
                                child: ListTile(
                                  onTap: () {
                                    MessageBloc customBloc = MessageBloc(chat, canLoadMore: false);
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
                                  title: Text(chat?.title ?? "Unknown title",
                                      style: titleStyle),
                                  subtitle: RichText(
                                    text: TextSpan(children: spans),
                                  ),
                                  leading: ContactAvatarGroupWidget(
                                    chat: chat!,
                                    size: 40,
                                    editable: false,
                                  ),
                                  minVerticalPadding: 10,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(buildDate(message.dateCreated),
                                        style: context.theme.textTheme.bodySmall!.copyWith(
                                          color: context.theme.colorScheme.outline,
                                        ).apply(fontSizeFactor: SettingsManager().settings.skin.value == Skins.Material ? 1 : 1.1)),
                                      if (SettingsManager().settings.skin.value == Skins.iOS)
                                        Icon(
                                          CupertinoIcons.forward,
                                          color: context.theme.colorScheme.outline,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      )
                    : Container()
          ],
        ),
      ),
    );
  }
}
