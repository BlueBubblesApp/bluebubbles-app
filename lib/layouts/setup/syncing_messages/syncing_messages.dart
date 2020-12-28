import 'dart:async';

import 'package:bluebubbles/blocs/setup_bloc.dart';
import 'package:bluebubbles/layouts/setup/qr_scan/failed_to_scan_dialog.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SyncingMessages extends StatefulWidget {
  SyncingMessages({Key key, @required this.controller}) : super(key: key);
  final PageController controller;

  @override
  _SyncingMessagesState createState() => _SyncingMessagesState();
}

class _SyncingMessagesState extends State<SyncingMessages> {
  @override
  void initState() {
    super.initState();
    StreamSubscription subscription;
    subscription = SocketManager().setup.stream.listen((event) async {
      if (event.progress == -1) {
        subscription.cancel();
        await showDialog(
          context: context,
          builder: (context) => FailedToScan(
              exception: event.output.last.text,
              title: "An error occured during setup!"),
        );

        widget.controller.animateToPage(
          3,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } else if (event.progress == 1.0) {
        subscription.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).accentColor,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).accentColor,
        body: StreamBuilder(
          stream: SocketManager().setup.stream,
          builder: (BuildContext context, AsyncSnapshot<SetupData> snapshot) {
            double progress = SocketManager().setup.progress;
            if (snapshot.hasData && snapshot.data.progress >= 0) {
              progress = snapshot.data.progress;
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Spacer(
                      flex: 100,
                    ),
                    Text(
                      "${(progress * 100).floor()}%",
                      style: Theme.of(context)
                          .textTheme
                          .bodyText1
                          .apply(fontSizeFactor: 1.5),
                    ),
                    Spacer(
                      flex: 5,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width / 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: progress != 1.0 && progress != 0.0
                              ? progress
                              : null,
                          backgroundColor: Colors.white,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor),
                        ),
                      ),
                    ),
                    Spacer(
                      flex: 20,
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 4 / 5,
                      height: MediaQuery.of(context).size.height * 1 / 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: EdgeInsets.all(10),
                        child: ListView.builder(
                          physics: AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics()),
                          itemBuilder: (context, index) {
                            SetupOutputData data =
                                snapshot.data.output.reversed.toList()[index];
                            return Text(
                              data.text,
                              style: TextStyle(
                                color: data.type == SetupOutputType.LOG
                                    ? Colors.grey
                                    : Colors.red,
                                fontSize: 10,
                              ),
                            );
                          },
                          itemCount: snapshot.data.output.length,
                        ),
                      ),
                    ),
                    Spacer(
                      flex: 100,
                    ),
                  ],
                ),
              );
            } else {
              return Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width / 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Spacer(
                        flex: 100,
                      ),
                      Text(
                        progress == 0.0
                            ? "Starting setup"
                            : progress == -1.0
                                ? "Cancelling..."
                                : "Finishing setup",
                        style: Theme.of(context).textTheme.bodyText1,
                      ),
                      Spacer(
                        flex: 5,
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.white,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor),
                        ),
                      ),
                      Spacer(
                        flex: 100,
                      ),
                    ],
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
