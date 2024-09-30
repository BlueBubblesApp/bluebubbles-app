import 'dart:async';

import 'package:bluebubbles/app/layouts/chat_creator/widgets/chat_creator_tile.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/window_effect.dart';
import 'package:get/get.dart' hide Response;
import 'package:slugify/slugify.dart';
import 'package:supercharged/supercharged.dart';

class ChatSelectorView extends StatefulWidget {
  const ChatSelectorView({
    super.key,
    required this.onSelect,
  });

  final void Function(Chat) onSelect;

  @override
  ChatSelectorViewState createState() => ChatSelectorViewState();
}

class ChatSelectorViewState extends OptimizedState<ChatSelectorView> {
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchNode = FocusNode();
  final ScrollController addressScrollController = ScrollController();

  List<Chat> filteredChats = [];
  String? oldSearch;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    // Handle searching for a chat
    searchController.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () async {
        final searchChats = await SchedulerBinding.instance.scheduleTask(() async {
          final query = slugify(searchController.text, delimiter: "");
          return GlobalChatService.chats.filter((element) => slugify(element.getTitle(), delimiter: "").contains(query));
        }, Priority.animation);

        _debounce = null;
        setState(() {
          filteredChats = List<Chat>.from(searchChats);
        });
      });
    });

    updateObx(() {
      if (GlobalChatService.chatsLoaded) {
        setState(() {
          filteredChats = List<Chat>.from(GlobalChatService.chats);
        });
      } else {
        GlobalChatService.chatsLoadedFuture.future.then((_) {
          setState(() {
            filteredChats = List<Chat>.from(GlobalChatService.chats);
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: ss.settings.immersiveMode.value
            ? Colors.transparent
            : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness.opposite,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Scaffold(
        backgroundColor: ss.settings.windowEffect.value != WindowEffect.disabled
            ? Colors.transparent
            : context.theme.colorScheme.background,
        appBar: PreferredSize(
            preferredSize: Size(ns.width(context), kIsDesktop ? 90 : 50),
            child: AppBar(
                systemOverlayStyle: context.theme.colorScheme.brightness == Brightness.dark
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark,
                toolbarHeight: kIsDesktop ? 90 : 50,
                elevation: 0,
                scrolledUnderElevation: 3,
                surfaceTintColor: context.theme.colorScheme.primary,
                leading: buildBackButton(context),
                backgroundColor: Colors.transparent,
                centerTitle: ss.settings.skin.value == Skins.iOS,
                title: Text(
                  "Select a Chat",
                  style: context.theme.textTheme.titleLarge,
                ))),
        body: FocusScope(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: TextField(
                  controller: searchController,
                  focusNode: searchNode,
                  style: context.theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                      hintText: "Search for a chat...",
                      hintStyle: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.outline),
                      prefixIcon: Icon(
                        Icons.search,
                        color: context.theme.colorScheme.outline,
                      ),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      filled: false),
                ),
              ),
              Expanded(
                child: Obx(() {
                  return Align(
                      alignment: Alignment.topCenter,
                      child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          child: CustomScrollView(
                            shrinkWrap: true,
                            physics: ThemeSwitcher.getScrollPhysics(),
                            slivers: <Widget>[
                              SliverList(
                                delegate: SliverChildBuilderDelegate((context, index) {
                                  if (filteredChats.isEmpty) {
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "Loading chats...",
                                            style: context.theme.textTheme.labelLarge,
                                          ),
                                        ),
                                        buildProgressIndicator(context, size: 15),
                                      ],
                                    );
                                  }
                                  final chat = filteredChats[index];
                                  final hideInfo = ss.settings.redactedMode.value && ss.settings.hideContactInfo.value;
                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        widget.onSelect(chat);
                                        Get.back();
                                      },
                                      child: ChatCreatorTile(
                                        key: ValueKey(chat.guid),
                                        title: chat.observables.title.value ?? "Unknown",
                                        subtitle: hideInfo
                                            ? ""
                                            : !chat.isGroup
                                                ? (chat.observables.participants.first.formattedAddress ??
                                                    chat.observables.participants.first.address)
                                                : chat.getChatCreatorSubtitle(),
                                        chat: chat,
                                        showTrailing: false,
                                      ),
                                    ),
                                  );
                                },
                                    childCount: filteredChats.length
                                        .clamp(GlobalChatService.chatsLoaded ? 0 : 1, double.infinity)
                                        .toInt()),
                              )
                            ],
                          )));
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
