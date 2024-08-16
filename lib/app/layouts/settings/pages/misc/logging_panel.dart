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
  final RxBool errorsOnly = false.obs;
  final RxList<String> _logs = <String>[].obs;
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    loadLogs();
  }

  void loadLogs([bool errorOnly = false]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Logger.getLogs(maxLines: 500).then((value) {
        _logs.clear();

        if (errorOnly) {
          _logs.addAll(value.where((element) => element.startsWith('[ERROR]')));
        } else {
          _logs.addAll(value);
        }
        
        _scrollToBottom();
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
                      // Menu button with 2 options, Play/Pause and Clear
                      PopupMenuButton(
                        icon: const Icon(Icons.more_vert),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            child: Obx(
                              () => ListTile(
                                leading: errorsOnly.value ? const Icon(Icons.file_copy_outlined) : const Icon(Icons.error_outline),
                                title: Text(errorsOnly.value ? "Show All Logs" : "Show Only Errors"),
                                onTap: () {
                                  errorsOnly.toggle();
                                  if (errorsOnly.value) {
                                    loadLogs(true);
                                  } else {
                                    loadLogs(false);
                                  }
                                },
                              ),
                            ),
                          ),
                          PopupMenuItem(
                            child: ListTile(
                              leading: const Icon(Icons.refresh),
                              title: const Text("Refresh"),
                              onTap: () {
                                _logs.clear();
                                loadLogs(errorsOnly.value);
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                  child: (_logs.isEmpty)
                    ? const Center(
                        child: Text(
                          "No logs to display",
                          style: TextStyle(fontSize: 16.0),
                        ),
                      )
                    : ListView.separated(
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
                      )
                    ),
            ),
          ),
        ));
  }
}
