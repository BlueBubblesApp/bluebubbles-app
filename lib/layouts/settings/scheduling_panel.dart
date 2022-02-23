import 'dart:ui';

import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/scheduler_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_improved_scrolling/flutter_improved_scrolling.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class SchedulingPanel extends StatefulWidget {
  SchedulingPanel({Key? key}) : super(key: key);

  @override
  _SchedulingPanelState createState() => _SchedulingPanelState();
}

class _SchedulingPanelState extends State<SchedulingPanel> {
  List<ScheduledMessage> scheduled = [];
  final scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    scheduled = ScheduledMessage.find();
  }

  List<TableRow> _buildRows(Iterable<ScheduledMessage> messages) {
    List<TableRow> rows = [];

    for (ScheduledMessage msg in messages) {
      DateTime time = DateTime.fromMillisecondsSinceEpoch(msg.epochTime!);
      String timeStr = DateFormat.yMd().add_jm().format(time).replaceFirst(" ", "\n");
      rows.add(TableRow(children: [
        Padding(
          padding: EdgeInsets.all(10.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Chat",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyText1,
              ),
              Text(msg.message!,
                  maxLines: 4, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.subtitle1)
            ],
          ),
        ),
        Padding(
            padding: EdgeInsets.all(10.0),
            child: Text(
              timeStr,
              textAlign: TextAlign.right,
            )),
      ]));
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    Iterable<ScheduledMessage> upcoming = scheduled.where((item) => now.millisecondsSinceEpoch <= item.epochTime!);
    Iterable<ScheduledMessage> old = scheduled.where((item) => now.millisecondsSinceEpoch > item.epochTime!);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
            Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
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
                systemOverlayStyle: getBrightness(context),
                toolbarHeight: 100.0,
                elevation: 0,
                leading: buildBackButton(context),
                backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
                title: Text(
                  "Message Scheduling",
                  style: Theme.of(context).textTheme.headline1,
                ),
              ),
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            ),
          ),
        ),
        body: ImprovedScrolling(
          enableMMBScrolling: true,
          mmbScrollConfig: MMBScrollConfig(
            customScrollCursor: DefaultCustomScrollCursor(
              cursorColor: context.textTheme.subtitle1!.color!,
              backgroundColor: Colors.white,
              borderColor: context.textTheme.headline1!.color!,
            ),
          ),
          scrollController: scrollController,
          child: CustomScrollView(
            controller: scrollController,
            physics: ThemeSwitcher.getScrollPhysics(),
            slivers: <Widget>[
              SliverList(
                delegate: SliverChildListDelegate(
                  <Widget>[
                    Padding(
                        padding: EdgeInsets.fromLTRB(25.0, 25.0, 25.0, 0.0),
                        child: Text("Upcoming Messages", style: Theme.of(context).textTheme.headline1)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 25.0, vertical: 25.0),
                      child: (upcoming.isNotEmpty)
                          ? Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.secondary,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.all(Radius.circular(10)),
                              ),
                              child: Table(
                                  columnWidths: {
                                    0: FractionColumnWidth(.6),
                                    1: FractionColumnWidth(.4),
                                  },
                                  border: TableBorder.symmetric(
                                    inside: BorderSide(width: 1, color: Theme.of(context).colorScheme.secondary),
                                  ),
                                  children: _buildRows(upcoming)))
                          : Text("No upcoming messages to send",
                              textAlign: TextAlign.left, style: Theme.of(context).textTheme.subtitle1),
                    ),
                    Padding(
                        padding: EdgeInsets.fromLTRB(25.0, 25.0, 25.0, 0.0),
                        child: Text("Past Messages", style: Theme.of(context).textTheme.headline1)),
                    Padding(
                        padding: EdgeInsets.symmetric(horizontal: 25.0, vertical: 25.0),
                        child: (old.isNotEmpty)
                            ? Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.secondary,
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                                child: Table(
                                    columnWidths: {
                                      0: FractionColumnWidth(.6),
                                      1: FractionColumnWidth(.4),
                                    },
                                    border: TableBorder.symmetric(
                                      inside: BorderSide(width: 1, color: Theme.of(context).colorScheme.secondary),
                                    ),
                                    children: _buildRows(old)))
                            : Text("No scheduled messages have been sent",
                                textAlign: TextAlign.left, style: Theme.of(context).textTheme.subtitle1)),
                  ],
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate(
                  <Widget>[],
                ),
              )
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Theme.of(context).primaryColor,
          child: Icon(Icons.create, color: Colors.white, size: 25),
          onPressed: () async {
            Navigator.of(context).push(
              ThemeSwitcher.buildPageRoute(
                builder: (BuildContext context) {
                  return SchedulePanel(chat: Chat(guid: 'tmp'));
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
