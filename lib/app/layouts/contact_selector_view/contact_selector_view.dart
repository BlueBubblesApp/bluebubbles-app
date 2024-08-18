import 'dart:async';

import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
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

class ContactSelectorView extends StatefulWidget {
  const ContactSelectorView({
    super.key,
    required this.onSelect,
  });

  final void Function(Contact) onSelect;

  @override
  ContactSelectorViewState createState() => ContactSelectorViewState();
}

class ContactSelectorViewState extends OptimizedState<ContactSelectorView> {
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchNode = FocusNode();
  final ScrollController addressScrollController = ScrollController();

  List<Contact> filteredContacts = [];
  String? oldSearch;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    // Handle searching for a contact
    searchController.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () async {
        final searchContacts = await SchedulerBinding.instance.scheduleTask(() async {
          final query = slugify(searchController.text, delimiter: "");
          return cs.contacts.filter((element) =>
              slugify(element.displayName, delimiter: "").contains(query) || element.hasMatchingAddress(query));
        }, Priority.animation);

        _debounce = null;
        setState(() {
          filteredContacts = List<Contact>.from(searchContacts);
        });
      });
    });

    setState(() {
      filteredContacts = List<Contact>.from(cs.contacts);
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
                  "Select a Contact",
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
                      hintText: "Search for a contact...",
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
                                  if (filteredContacts.isEmpty) {
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "Loading contacts...",
                                            style: context.theme.textTheme.labelLarge,
                                          ),
                                        ),
                                        buildProgressIndicator(context, size: 15),
                                      ],
                                    );
                                  }
                                  final contact = filteredContacts[index];
                                  final hideInfo = ss.settings.redactedMode.value && ss.settings.hideContactInfo.value;
                                  String _title = contact.displayName;
                                  if (hideInfo) {
                                    _title = "Contact";
                                  }

                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        widget.onSelect(contact);
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
                                          leading: Padding(
                                            padding: const EdgeInsets.only(right: 5.0),
                                            child: ContactAvatarWidget(
                                              contact: contact,
                                              editable: false,
                                            ),
                                          )),
                                    ),
                                  );
                                }, childCount: filteredContacts.length.clamp(1, double.infinity).toInt()),
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
