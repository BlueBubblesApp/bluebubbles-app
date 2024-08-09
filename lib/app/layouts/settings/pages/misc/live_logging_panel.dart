import 'dart:ui';

import 'package:bluebubbles/app/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';

class LiveLoggingPanel extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _LiveLoggingPanel();
}

class _LiveLoggingPanel extends State<LiveLoggingPanel> {
  RxBool isPaused = false.obs;

  final List<String> _logs = [];
  final ScrollController scrollController = ScrollController();
  bool _shouldAutoScroll = true;

  @override
  void initState() {
    super.initState();
    Logger.enableLiveLogging();

    scrollController.addListener(() {
      // Check if the user has scrolled up.
      if (scrollController.position.atEdge) {
        _shouldAutoScroll = scrollController.position.pixels != 0;
      } else {
        _shouldAutoScroll = false;
      }
    });

    Logger.logStream.stream.listen((event) {
      if (_shouldAutoScroll) {
        _scrollToBottom();
      }

      // Trim the logs list if it reaches out "max" which will be 500
      if (_logs.length > 500) {
        _logs.removeAt(0);
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    Logger.disableLiveLogging();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });
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
                      "Live Logging",
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
                                title: Text(isPaused.value ? "Play" : "Pause"),
                                onTap: () {
                                  isPaused.toggle();
                                  if (isPaused.value) {
                                    Logger.disableLiveLogging();
                                  } else {
                                    Logger.enableLiveLogging();
                                  }
                                },
                              ),
                            ),
                          ),
                          PopupMenuItem(
                            child: ListTile(
                              title: const Text("Clear"),
                              onTap: () {
                                _logs.clear();
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
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: StreamBuilder<String>(
                  stream: Logger.logStream.stream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Text('Waiting for logs...'));
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (snapshot.hasData) {
                      _logs.add(snapshot.data!);
                    }

                    return ListView.separated(
                      itemCount: _logs.length,
                      shrinkWrap: true,
                      controller: scrollController,

                      separatorBuilder: (context, index) => Divider(thickness: 0.25, color: context.theme.colorScheme.onSurface),
                      itemBuilder: (context, index) {
                        Color textColor = Colors.black;
                        if (_logs[index].startsWith('[ERROR]')) {
                          textColor = Colors.red;
                        } else if (_logs[index].startsWith('[WARNING]')) {
                          textColor = Colors.orange;
                        } else if (_logs[index].startsWith('[TRACE]')) {
                          textColor = context.theme.colorScheme.primary;
                        } else if (_logs[index].startsWith('[FATAL]')) {
                          textColor = Colors.red;
                        } else if (_logs[index].startsWith('[DEBUG]')) {
                          textColor = context.theme.colorScheme.secondary;
                        }

                        return Text(
                          _logs[index].trim(),
                          style: TextStyle(fontSize: 12.0, color: textColor),
                        );
                      },
                    );
                  },
                )
              ),
            ),
          ),
        ));
  }
}
