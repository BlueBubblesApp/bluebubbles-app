import 'package:bluebubbles/blocs/setup_bloc.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_list.dart';
import 'package:bluebubbles/layouts/setup/qr_scan/failed_to_scan_dialog.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class SyncingMessages extends StatefulWidget {
  SyncingMessages({Key? key, required this.controller}) : super(key: key);
  final PageController controller;

  @override
  _SyncingMessagesState createState() => _SyncingMessagesState();
}

class _SyncingMessagesState extends State<SyncingMessages> {
  @override
  void initState() {
    super.initState();
    ever<SetupData?>(SocketManager().setup.data, (event) async {
      if (event?.progress == -1) {
        await showDialog(
          context: context,
          builder: (context) =>
              FailedToScan(exception: event?.output.last.text, title: "An error occured during setup!"),
        );

        widget.controller.animateToPage(
          3,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } else if ((event?.progress ?? 0) >= 100) {
        /*widget.controller.nextPage(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );*/
        SocketManager().toggleSetupFinished(true, applyToDb: true);
        Get.offAll(
            () => ConversationList(
                  showArchivedChats: false,
                  showUnknownSenders: false,
                ),
            duration: Duration.zero,
            transition: Transition.noTransition);
      }
    });
  }

  String getProgressText(double progress) {
    String txt = 'Setup in progress';
    if (progress == 0.0) {
      txt = 'Starting setup';
    } else if (progress == -1.0) {
      txt = 'Cancelling';
    } else if (progress >= 100) {
      txt = 'Finishing setup';
    }

    return '$txt...';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
            Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        body: Obx(() {
          double progress = SocketManager().setup.progress;
          if ((SocketManager().setup.data.value?.progress ?? 0) >= 0) {
            progress = SocketManager().setup.data.value?.progress ?? 0;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Spacer(
                    flex: 100,
                  ),
                  Text(
                    "${progress.floor()}%",
                    style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeFactor: 1.5),
                  ),
                  Spacer(
                    flex: 5,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: CustomNavigator.width(context) / 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: progress != 100.0 && progress != 0.0 ? (progress / 100) : null,
                        backgroundColor: Colors.white,
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                      ),
                    ),
                  ),
                  Spacer(
                    flex: 20,
                  ),
                  SizedBox(
                    width: CustomNavigator.width(context) * 4 / 5,
                    height: context.height * 1 / 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: EdgeInsets.all(10),
                      child: ListView.builder(
                        physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        itemBuilder: (context, index) {
                          SetupOutputData data = SocketManager().setup.data.value?.output.reversed.toList()[index] ??
                              SetupOutputData("Unknown", SetupOutputType.ERROR);
                          return Text(
                            data.text,
                            style: TextStyle(
                              color: data.type == SetupOutputType.LOG ? Colors.grey : Colors.red,
                              fontSize: 10,
                            ),
                          );
                        },
                        itemCount: SocketManager().setup.data.value?.output.length ?? 0,
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
                padding: EdgeInsets.symmetric(horizontal: CustomNavigator.width(context) / 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Spacer(
                      flex: 100,
                    ),
                    Text(
                      getProgressText(progress),
                      style: Theme.of(context).textTheme.bodyText1,
                    ),
                    Spacer(
                      flex: 5,
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.white,
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
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
        }),
      ),
    );
  }
}
