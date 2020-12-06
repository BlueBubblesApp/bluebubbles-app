import 'dart:ui';

import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/helpers/contstants.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SearchView extends StatefulWidget {
  SearchView({
    Key key,
  }) : super(key: key);

  @override
  SearchViewState createState() => SearchViewState();
}

class SearchViewState extends State<SearchView> with TickerProviderStateMixin {
  List<dynamic> results = [];

  GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final Duration animationDuration = Duration(milliseconds: 400);
  final TextEditingController textEditingController =
      new TextEditingController();

  Brightness brightness;
  bool gotBrightness = false;
  bool isSearching = false;
  Map<String, Chat> chatCache = {};

  @override
  void initState() {
    super.initState();

    // Listen for any incoming events
    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!event.containsKey("type")) return;
      if (event["type"] == 'theme-update' && this.mounted) {
        setState(() {
          gotBrightness = false;
        });
      }
    });
  }

  void loadBrightness() {
    if (gotBrightness) return;
    if (context == null) {
      brightness = Brightness.light;
      gotBrightness = true;
      return;
    }

    bool isDark = Theme.of(context).backgroundColor.computeLuminance() < 0.179;
    brightness = isDark ? Brightness.dark : Brightness.light;
    gotBrightness = true;
  }

  Future<void> search(String term) async {
    if (isSearching || isNullOrEmpty(term) || term.length < 3) return;
    if (this.mounted)
      setState(() {
        isSearching = true;
      });

    List<dynamic> results =
        await SocketManager().fetchMessages(null, limit: 50, where: [
      {
        'statement': 'message.text LIKE :term',
        'args': {'term': "%${textEditingController.text}%"}
      }
    ]);

    List<dynamic> _results = [];
    for (dynamic item in results) {
      // Build the data map
      Map<String, dynamic> data = {
        'message': Message.fromMap(item),
        'chat': Chat.fromMap(item['chats'][0])
      };

      // If we've already got this chat, use the cached one
      if (chatCache.containsKey(data['chat'].guid)) {
        data['chat'] = chatCache[data['chat'].guid];
      } else {
        data['chat'] = await Chat.findOne({'guid': data['chat'].guid});

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
    _listKey = new GlobalKey<AnimatedListState>();

    // Let the animated list know it should update
    _listKey?.currentState?.setState(() {});

    // Update the UI with the results
    if (this.mounted) {
      setState(() {
        isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    loadBrightness();
    print("REBUILDING");
    print(results.length);

    return Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        appBar: PreferredSize(
          preferredSize: Size(MediaQuery.of(context).size.width, 80),
          child: ClipRRect(
            child: BackdropFilter(
              child: AppBar(
                brightness: brightness,
                toolbarHeight: 100.0,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(SettingsManager().settings.skin == Skins.IOS ? Icons.arrow_back_ios : Icons.arrow_back,
                      color: Theme.of(context).primaryColor),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                backgroundColor: Theme.of(context).accentColor.withOpacity(0.5),
                title: Text(
                  "Search",
                  style: Theme.of(context).textTheme.headline1,
                ),
              ),
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            ),
          ),
        ),
        body: Column(children: [
          Container(padding: EdgeInsets.only(top: 8.0)),
          Container(
              padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.search,
                        color: Theme.of(context).textTheme.bodyText1.color),
                    Container(padding: EdgeInsets.only(right: 5.0)),
                    Flexible(
                        fit: FlexFit.loose,
                        child: CupertinoTextField(
                          padding: EdgeInsets.symmetric(
                              horizontal: 15.0, vertical: 10),
                          controller: textEditingController,
                          placeholder: "Enter a search term...",
                          style: Theme.of(context).textTheme.bodyText1,
                          placeholderStyle:
                              Theme.of(context).textTheme.subtitle1,
                          decoration: BoxDecoration(
                              color: Theme.of(context).backgroundColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Theme.of(context).accentColor)),
                          maxLines: 1,
                        )),
                    (!this.isSearching)
                        ? CupertinoButton(
                            padding: EdgeInsets.all(0),
                            child: Icon(Icons.arrow_forward,
                                color:
                                    Theme.of(context).textTheme.bodyText1.color,
                                size: 30),
                            onPressed: () {
                              search(textEditingController.text);
                            })
                        : Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Theme(
                              data: ThemeData(
                                cupertinoOverrideTheme:
                                    CupertinoThemeData(brightness: brightness),
                              ),
                              child: CupertinoActivityIndicator(),
                            ),
                          )
                  ])),
          Divider(color: Theme.of(context).accentColor),
          Flexible(
            fit: FlexFit.loose,
            child: AnimatedList(
              key: _listKey,
              initialItemCount: results.length,
              itemBuilder: (BuildContext context, int index,
                  Animation<double> animation) {
                print(this.results[index]);
                Message message = results[index]['message'];
                Chat chat = results[index]['chat'];

                // Create the textspans
                List<InlineSpan> spans = [];

                // Get the current position of the search term
                int termIndex = (message.text ?? "")
                    .toLowerCase()
                    .indexOf(textEditingController.text.toLowerCase());
                int termEnd = termIndex + textEditingController.text.length;

                if (termIndex >= 0) {
                  // We only want a snippet of the text, so only get a 50x50 range
                  // of characters from the string, with the search term in the middle
                  String subText = message.text.substring(
                      (termIndex - 50 >= 0) ? termIndex - 50 : 0,
                      (termEnd + 50 < message.text.length)
                          ? termEnd + 50
                          : message.text.length);

                  // Recarculate the term position in the snippet
                  termIndex = subText
                      .toLowerCase()
                      .indexOf(textEditingController.text.toLowerCase());
                  termEnd = termIndex + textEditingController.text.length;

                  // Add the beginning string
                  spans.add(TextSpan(
                      text: subText.substring(0, termIndex).trimLeft(),
                      style: Theme.of(context).textTheme.subtitle1));

                  // Add the search term
                  spans.add(TextSpan(
                      text: subText.substring(termIndex, termEnd),
                      style: Theme.of(context).textTheme.subtitle1.apply(
                          color: Theme.of(context).primaryColor,
                          fontWeightDelta: 2)));

                  // Add the ending string
                  spans.add(TextSpan(
                      text: subText
                          .substring(termEnd, subText.length)
                          .trimRight(),
                      style: Theme.of(context).textTheme.subtitle1));
                } else {
                  spans.add(TextSpan(
                      text: message.text,
                      style: Theme.of(context).textTheme.subtitle1));
                }

                return Column(
                    key: new Key("result-${message.guid}"),
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      ListTile(
                          dense: true,
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text("${dateToShortString(message.dateCreated)}",
                                  style: Theme.of(context)
                                      .textTheme
                                      .subtitle1
                                      .apply(fontSizeDelta: -2)),
                              Container(height: 5.0),
                              Text(chat?.title,
                                  style: Theme.of(context).textTheme.bodyText1),
                            ],
                          ),
                          subtitle: Padding(
                              padding: EdgeInsets.only(top: 5.0),
                              child: RichText(text: TextSpan(children: spans))),
                          trailing: Icon(Icons.arrow_forward_ios,
                              color:
                                  Theme.of(context).textTheme.bodyText1.color)),
                      Divider(color: Theme.of(context).accentColor)
                    ]);
              },
            ),
          )
        ]));
  }
}
