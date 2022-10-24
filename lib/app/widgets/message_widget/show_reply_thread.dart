import 'dart:ui';

import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_widget.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

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
      transitionDuration: Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        Future.delayed(Duration.zero, () => controller.jumpTo(controller.position.maxScrollExtent));
        return FadeTransition(
            opacity: animation,
            child: Theme(
              data: context.theme.copyWith(
                // in case some components still use legacy theming
                primaryColor: context.theme.colorScheme.bubble(context, true),
                colorScheme: context.theme.colorScheme.copyWith(
                  primary: context.theme.colorScheme.bubble(context, true),
                  onPrimary: context.theme.colorScheme.onBubble(context, true),
                  surface: ss.settings.monetTheming.value == Monet.full ? null : (context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor,
                  onSurface: ss.settings.monetTheming.value == Monet.full ? null : (context.theme.extensions[BubbleColors] as BubbleColors?)?.onReceivedBubbleColor,
                ),
              ),
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle(
                    systemNavigationBarColor: ss.settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
                    systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
                    statusBarColor: Colors.transparent, // status bar color
                    statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
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
                                        olderMessage: index > 0 ? _messages[index - 1] : null,
                                        newerMessage: index < _messages.length - 1 ? _messages[index + 1] : null,
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
              ),
            )
        );
      },
      fullscreenDialog: true,
      opaque: false,
    ),
  );
}