import 'dart:ui';

import 'package:bluebubbles/app/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';

class LoggingPanel extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _LoggingPanel();
}

class _LoggingPanel extends State<LoggingPanel> {
  final RxBool isLoading = false.obs;
  final RxList<String> _logs = <String>[].obs;
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    loadLogs();
  }

  void loadLogs() {
    isLoading.value = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Logger.getLogs(maxLines: 500).then((value) {
        _logs.addAll(value);
        
        _scrollToBottom();
        isLoading.value = false;
      });
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        // Keep scrolling until the scroll position is at the bottom
        if (scrollController.position.pixels != scrollController.position.maxScrollExtent) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );

          Future.delayed(const Duration(milliseconds: 500), () {
            _scrollToBottom();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Rx<Color> _backgroundColor =
        (kIsDesktop && ss.settings.windowEffect.value == WindowEffect.disabled
                ? Colors.transparent
                : context.theme.colorScheme.background)
            .obs;

    if (kIsDesktop) {
      ss.settings.windowEffect.listen((WindowEffect effect) =>
          _backgroundColor.value = effect != WindowEffect.disabled
              ? Colors.transparent
              : context.theme.colorScheme.background);
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          systemNavigationBarColor: ss.settings.immersiveMode.value
              ? Colors.transparent
              : context.theme.colorScheme.background, // navigation bar color
          systemNavigationBarIconBrightness:
              context.theme.colorScheme.brightness.opposite,
          statusBarColor: Colors.transparent, // status bar color
          statusBarIconBrightness:
              context.theme.colorScheme.brightness.opposite,
        ),
        child: Obx(
          () => Scaffold(
            backgroundColor: _backgroundColor.value,
            appBar: PreferredSize(
              preferredSize: Size(ns.width(context), 80),
              child: ClipRRect(
                child: BackdropFilter(
                  child: AppBar(
                    systemOverlayStyle: ThemeData.estimateBrightnessForColor(
                                context.theme.colorScheme.background) ==
                            Brightness.dark
                        ? SystemUiOverlayStyle.light
                        : SystemUiOverlayStyle.dark,
                    toolbarHeight: kIsDesktop ? 80 : 50,
                    elevation: 0,
                    scrolledUnderElevation: 3,
                    surfaceTintColor: context.theme.colorScheme.primary,
                    leading: buildBackButton(context),
                    backgroundColor: _backgroundColor.value,
                    centerTitle: ss.settings.skin.value == Skins.iOS,
                    title: Text(
                      "Logs",
                      style: context.theme.textTheme.titleLarge,
                    ),
                    actions: [
                      // Animated refresh button that spins when clicked
                      Obx(() => IconButton(
                            icon: Icon(
                              Icons.refresh,
                              color: context.theme.colorScheme.primary,
                              size: 30,
                            ),
                            onPressed: isLoading.value
                                ? null
                                : () => loadLogs()
                          )),
                    ],
                  ),
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                ),
              ),
            ),
            body: ScrollbarWrapper(
              showScrollbar: true,
              controller: scrollController,
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: ListView.separated(
                    itemCount: _logs.length,
                    shrinkWrap: true,
                    controller: scrollController,
                    separatorBuilder: (context, index) => Divider(
                        thickness: 0.25,
                        color: context.theme.colorScheme.onSurface),
                    itemBuilder: (context, index) {
                      String log = _logs[index].trim();

                      // Remove date
                      log = log.split(' ').sublist(1).join(' ');

                      // Print colorful
                      Color textColor = context.theme.colorScheme.primary;
                      if (log.startsWith('[ERROR]')) {
                        textColor = Colors.red;
                      } else if (log.startsWith('[WARNING]')) {
                        textColor = Colors.orange;
                      } else if (log.startsWith('[TRACE]')) {
                        textColor = context.theme.colorScheme.primary;
                      } else if (log.startsWith('[FATAL]')) {
                        textColor = Colors.red;
                      } else if (log.startsWith('[DEBUG]')) {
                        textColor = context.theme.colorScheme.secondary;
                      }

                      return Text(
                        log,
                        style: TextStyle(fontSize: 12.0, color: textColor),
                      );
                    },
                  )),
            ),
          ),
        ));
  }
}