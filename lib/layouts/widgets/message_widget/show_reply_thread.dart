import 'dart:ui';

import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_widget.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void showReplyThread(BuildContext context, Message message, MessageBloc? messageBloc) {
  List<Message> _messages = [];
  if (message.threadOriginatorGuid != null) {
    _messages = messageBloc?.messages.values.where((e) => e.threadOriginatorGuid == message.threadOriginatorGuid || e.guid == message.threadOriginatorGuid).toList() ?? [];
  } else {
    _messages = messageBloc?.messages.values.where((e) => e.threadOriginatorGuid == message.guid || e.guid == message.guid).toList() ?? [];
  }
  _messages.sort((a, b) => a.dateCreated!.compareTo(b.dateCreated!));
  final controller = ScrollController();
  Navigator.push(
    context,
    PageRouteBuilder(
      settings: RouteSettings(arguments: {"hideTail": true}),
      transitionDuration: Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        Future.delayed(Duration.zero, () => controller.jumpTo(controller.position.maxScrollExtent));
        return FadeTransition(
            opacity: animation,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
              },
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : Theme.of(context).backgroundColor, // navigation bar color
                  systemNavigationBarIconBrightness:
                  Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
                  statusBarColor: Colors.transparent, // status bar color
                ),
                child: Scaffold(
                  backgroundColor: Colors.transparent,
                  body: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Center(
                          child: ListView.builder(
                            shrinkWrap: true,
                            controller: controller,
                            itemBuilder: (context, index) {
                              return AbsorbPointer(
                                absorbing: true,
                                child: Padding(
                                    padding: EdgeInsets.only(left: 5.0, right: 5.0),
                                    child: MessageWidget(
                                      key: Key(_messages[index].guid!),
                                      message: _messages[index],
                                      olderMessage: null,
                                      newerMessage: null,
                                      showHandle: true,
                                      isFirstSentMessage: messageBloc!.firstSentMessage == _messages[index].guid,
                                      showHero: false,
                                      showReplies: false,
                                      bloc: messageBloc,
                                      autoplayEffect: false,
                                    )),
                              );
                            },
                            itemCount: _messages.length,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
        );
      },
      fullscreenDialog: true,
      opaque: false,
    ),
  );
}