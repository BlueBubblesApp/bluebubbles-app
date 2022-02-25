import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class PrepareToDownload extends StatefulWidget {
  PrepareToDownload({Key? key, required this.controller}) : super(key: key);
  final PageController controller;

  @override
  _PrepareToDownloadState createState() => _PrepareToDownloadState();
}

class _PrepareToDownloadState extends State<PrepareToDownload> {
  double numberOfMessages = 25;
  bool downloadAttachments = false;
  bool skipEmptyChats = true;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness: Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        body: LayoutBuilder(
          builder: (context, size) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: size.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 80.0, left: 20.0, right: 20.0, bottom: 40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: context.width * 2 / 3,
                                child: Text(
                                    "Sync Messages",
                                    style: Theme.of(context).textTheme.bodyText1!.apply(
                                      fontSizeFactor: 2.5,
                                      fontWeightDelta: 2,
                                    ).copyWith(height: 1.5)
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                  "We will now download the first ${numberOfMessages == 1 ? "message" : "${numberOfMessages.toString().split(".").first} messages"} for each of your chats.\nYou can see more messages by simply scrolling up in the chat.",
                                  style: Theme.of(context).textTheme.bodyText1!.apply(
                                    fontSizeFactor: 1.1,
                                    color: Colors.grey,
                                  ).copyWith(height: 2)
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                  "Note: If the syncing gets stuck, try reducing the number of messages to sync to 1.",
                                  style: Theme.of(context).textTheme.bodyText1!.apply(
                                    color: Colors.grey,
                                  ).copyWith(height: 1.5)
                              ),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          color: Theme.of(context).backgroundColor.computeLuminance() > 0.5
                              ? Theme.of(context).colorScheme.secondary.lightenPercent(50)
                              : Theme.of(context).colorScheme.secondary.darkenPercent(50),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "Sync Options",
                                style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeFactor: 1.25),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "Number of Messages to Sync Per Chat: $numberOfMessages",
                                style: Theme.of(context).textTheme.bodyText1!.apply(
                                  color: Colors.grey,
                                ).copyWith(height: 1.5),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(height: 10),
                            Slider(
                              value: numberOfMessages,
                              onChanged: (double value) {
                                if (!mounted) return;

                                setState(() {
                                  numberOfMessages = value == 0 ? 1 : value;
                                });
                              },
                              label: numberOfMessages == 0 ? "1" : numberOfMessages.toString(),
                              divisions: 10,
                              min: 0,
                              max: 50,
                            ),
                            SizedBox(height: 10),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 40.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Text(
                                    "Skip empty chats",
                                    style: Theme.of(context).textTheme.bodyText1!.apply(
                                      color: Colors.grey,
                                    ).copyWith(height: 1.5),
                                    textAlign: TextAlign.center,
                                  ),
                                  Switch(
                                    value: skipEmptyChats,
                                    activeColor: Theme.of(context).primaryColor,
                                    activeTrackColor: Theme.of(context).primaryColor.withAlpha(200),
                                    inactiveTrackColor: Theme.of(context).primaryColor.withAlpha(75),
                                    inactiveThumbColor: Theme.of(context).textTheme.bodyText1!.color,
                                    onChanged: (bool value) {
                                      if (!mounted) return;

                                      setState(() {
                                        skipEmptyChats = value;
                                      });
                                    },
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          gradient: LinearGradient(
                            begin: AlignmentDirectional.topStart,
                            colors: [HexColor('2772C3'), HexColor('5CA7F8').darkenPercent(5)],
                          ),
                        ),
                        height: 40,
                        child: ElevatedButton(
                          style: ButtonStyle(
                            shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20.0),
                              ),
                            ),
                            backgroundColor: MaterialStateProperty.all(Colors.transparent),
                            shadowColor: MaterialStateProperty.all(Colors.transparent),
                            maximumSize: MaterialStateProperty.all(Size(context.width * 2 / 3, 36)),
                            minimumSize: MaterialStateProperty.all(Size(context.width * 2 / 3, 36)),
                          ),
                          onPressed: () {
                            // Set the number of messages to sync
                            SocketManager().setup.numberOfMessagesPerPage = numberOfMessages;
                            SocketManager().setup.downloadAttachments = downloadAttachments;
                            SocketManager().setup.skipEmptyChats = skipEmptyChats;

                            // Start syncing
                            SocketManager().setup.startFullSync(SettingsManager().settings);
                            widget.controller.nextPage(
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.cloud_download,
                                color: Colors.white,
                              ),
                              SizedBox(width: 10),
                              Text(
                                  "Start Sync",
                                  style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeFactor: 1.1, color: Colors.white)
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        ),
      ),
    );
  }
}
