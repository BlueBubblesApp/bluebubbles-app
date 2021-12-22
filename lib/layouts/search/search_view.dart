import 'dart:ui';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

    List<dynamic> results = await SocketManager().fetchMessages(null, limit: 50, where: [
      {
        'statement': 'message.text LIKE :term',
        'args': {'term': "%${textEditingController.text}%"}
      },
      {'statement': 'message.associated_message_guid IS NULL', 'args': null}
    ])!;

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness: Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
        // extendBodyBehindAppBar: true,
        backgroundColor: Theme.of(context).backgroundColor,
        appBar: PreferredSize(
          preferredSize: Size(CustomNavigator.width(context), 80),
          child: ClipRRect(
            child: BackdropFilter(
              child: AppBar(
                systemOverlayStyle: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor) == Brightness.dark
                      ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
                toolbarHeight: 100.0,
                elevation: 0,
                leading: buildBackButton(context),
                backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
                title: Text(
                  "Search",
                  style: Theme.of(context).textTheme.headline1,
                ),
              ),
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            ),
          ),
        ),
        body: Column(
          children: [
            Container(padding: EdgeInsets.only(top: 8.0)),
            Container(
                padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.search : Icons.search, color: Theme.of(context).textTheme.bodyText1!.color),
                      Container(padding: EdgeInsets.only(right: 5.0)),
                      Flexible(
                          fit: FlexFit.loose,
                          child: CupertinoTextField(
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) {
                              search(textEditingController.text);
                            },
                            focusNode: _focusNode,
                            padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 10),
                            controller: textEditingController,
                            placeholder: "Enter a search term...",
                            style: Theme.of(context).textTheme.bodyText1,
                            placeholderStyle: Theme.of(context).textTheme.subtitle1,
                            decoration: BoxDecoration(
                                color: Theme.of(context).backgroundColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Theme.of(context).colorScheme.secondary)),
                            maxLines: 1,
                          )),
                      (!isSearching)
                          ? CupertinoButton(
                              padding: EdgeInsets.all(0),
                              child: Icon(Icons.arrow_forward,
                                  color: Theme.of(context).textTheme.bodyText1!.color, size: 30),
                              onPressed: () {
                                search(textEditingController.text);
                              })
                          : Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: SettingsManager().settings.skin.value == Skins.iOS ? Theme(
                                data: ThemeData(
                                  cupertinoOverrideTheme: CupertinoThemeData(
                                      brightness:
                                          ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor)),
                                ),
                                child: CupertinoActivityIndicator(),
                              ) : Container(height: 20, width: 20, child: Center(child: CircularProgressIndicator(strokeWidth: 2,))),
                            )
                    ])),
            Divider(color: Theme.of(context).colorScheme.secondary),
            (!isSearching && noResults)
                ? Padding(
                    padding: EdgeInsets.only(top: 25.0),
                    child: Text("No results found!", style: Theme.of(context).textTheme.bodyText1))
                : (!isSearching)
                    ? Flexible(
                        fit: FlexFit.loose,
                        child: AnimatedList(
                          key: _listKey,
                          initialItemCount: results.length,
                          itemBuilder: (BuildContext context, int index, Animation<double> animation) {
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
                                  style: Theme.of(context).textTheme.subtitle1));

                              // Add the search term
                              spans.add(TextSpan(
                                  text: subText.substring(termIndex, termEnd),
                                  style: Theme.of(context)
                                      .textTheme
                                      .subtitle1!
                                      .apply(color: Theme.of(context).primaryColor, fontWeightDelta: 2)));

                              // Add the ending string
                              spans.add(TextSpan(
                                  text: subText.substring(termEnd, subText.length).trimRight(),
                                  style: Theme.of(context).textTheme.subtitle1));
                            } else {
                              spans.add(TextSpan(text: message.text, style: Theme.of(context).textTheme.subtitle1));
                            }

                            return Column(
                              key: Key("result-${message.guid}"),
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                ListTile(
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
                                  dense: true,
                                  title: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Text(buildDate(message.dateCreated),
                                          style: Theme.of(context).textTheme.subtitle1!.apply(fontSizeDelta: -2)),
                                      Container(height: 5.0),
                                      Text(chat?.title ?? "Unknown title", style: Theme.of(context).textTheme.bodyText1),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: EdgeInsets.only(top: 5.0),
                                    child: RichText(
                                      text: TextSpan(children: spans),
                                    ),
                                  ),
                                  trailing: Icon(
                                    SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.forward : Icons.arrow_forward_ios,
                                    color: Theme.of(context).textTheme.bodyText1!.color,
                                  ),
                                ),
                                Divider(color: Theme.of(context).colorScheme.secondary)
                              ],
                            );
                          },
                        ),
                      )
                    : Container()
          ],
        ),
      ),
    );
  }
}
