import 'dart:async';

import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/string_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/window_effect.dart';
import 'package:get/get.dart' hide Response;
import 'package:slugify/slugify.dart';

class HandleSelectorView extends StatefulWidget {
  const HandleSelectorView({
    super.key,
    required this.onSelect,
    this.forChat,
  });

  final void Function(Handle) onSelect;
  final Chat? forChat;

  @override
  HandleSelectorViewState createState() => HandleSelectorViewState();
}

class HandleSelectorViewState extends OptimizedState<HandleSelectorView> {
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchNode = FocusNode();
  final ScrollController addressScrollController = ScrollController();

  Completer<void> loadedAllHandles = Completer<void>();
  List<Handle> handles = [];
  List<Handle> filteredHandles = [];
  String? oldSearch;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    // Handle searching for a handle
    searchController.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () async {
        final searchHandles = await SchedulerBinding.instance.scheduleTask(() async {
          final query = slugify(searchController.text, delimiter: "");
          return handles
              .where((element) =>
                  slugify(element.displayName, delimiter: "").contains(query) || element.address.contains(query))
              .toList();
        }, Priority.animation);

        _debounce = null;
        setState(() {
          filteredHandles = List<Handle>.from(searchHandles);
        });
      });
    });

    updateObx(() {
      if (loadedAllHandles.isCompleted) {
        setState(() {
          filteredHandles = List<Handle>.from(handles);
        });
      } else {
        loadedAllHandles.future.then((_) {
          setState(() {
            filteredHandles = List<Handle>.from(handles);
          });
        });
      }
    });

    loadHandles();
  }

  Future<void> loadHandles() async {
    handles = Database.handles.getAll();

    // Sort alphabetically, prioritizing handles with contact associations
    handles.sort((a, b) {
      if (a.contact != null && b.contact == null) {
        return -1;
      } else if (a.contact == null && b.contact != null) {
        return 1;
      } else {
        return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      }
    });

    // If there is a chat & participants, filter by participants
    if (widget.forChat != null && widget.forChat!.participants.isNotEmpty) {
      final addresses = widget.forChat!.participants.map((e) => e.address);
      handles = handles.where((element) => addresses.contains(element.address)).toList();
    }

    loadedAllHandles.complete();
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
                  "Select an Address",
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
                      hintText: "Search for an address...",
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
                                  if (filteredHandles.isEmpty) {
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "Loading handles...",
                                            style: context.theme.textTheme.labelLarge,
                                          ),
                                        ),
                                        buildProgressIndicator(context, size: 15),
                                      ],
                                    );
                                  }
                                  final handle = filteredHandles[index];
                                  final hideInfo = ss.settings.redactedMode.value && ss.settings.hideContactInfo.value;
                                  String _title = handle.displayName;
                                  if (hideInfo) {
                                    _title = handle.fakeName;
                                  }

                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                        onTap: () {
                                          widget.onSelect(handle);
                                          Get.back();
                                        },
                                        child: ListTile(
                                            mouseCursor: MouseCursor.defer,
                                            enableFeedback: true,
                                            dense: ss.settings.denseChatTiles.value,
                                            minVerticalPadding: 10,
                                            horizontalTitleGap: 10,
                                            title: RichText(
                                              text: TextSpan(
                                                children: MessageHelper.buildEmojiText(
                                                  _title,
                                                  context.theme.textTheme.bodyLarge!,
                                                ),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            subtitle: handle.address.isPhoneNumber
                                                ? FutureBuilder<String>(
                                                    future: formatPhoneNumber(cleansePhoneNumber(handle.address)),
                                                    initialData: handle.address,
                                                    builder: (context, snapshot) {
                                                      return Text(
                                                        snapshot.data ?? "",
                                                        style: context.theme.textTheme.bodySmall!
                                                            .copyWith(color: context.theme.colorScheme.outline),
                                                      );
                                                    },
                                                  )
                                                : Text(
                                                    handle.address,
                                                    style: context.theme.textTheme.bodySmall!
                                                        .copyWith(color: context.theme.colorScheme.outline),
                                                  ),
                                            leading: Padding(
                                              padding: const EdgeInsets.only(right: 5.0),
                                              child: ContactAvatarWidget(
                                                handle: handle,
                                                contact: handle.contact,
                                                editable: false,
                                              ),
                                            ))),
                                  );
                                },
                                    childCount: filteredHandles.length
                                        .clamp(loadedAllHandles.isCompleted ? 0 : 1, double.infinity)
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
