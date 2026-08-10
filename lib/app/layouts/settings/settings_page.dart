import 'package:bluebubbles/app/layouts/settings/pages/server/server_management_panel.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/search/searchable_setting_item.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/search/settings_search_breadcrumb_tile.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/search/settings_items_list.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/search/settings_search_bar.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/search/settings_search_empty_result.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/tablet_mode_wrapper.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.initialPage,
  });

  final Widget? initialPage;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

/// Drops the settings list's highlight once the right pane is back on its
/// placeholder route — nothing is open, so nothing should look selected.
/// Page switches remove routes rather than popping them, so they don't hit this.
class _SettingsPaneObserver extends NavigatorObserver {
  @override
  void didPop(Route route, Route? previousRoute) {
    if (previousRoute?.settings.name == "initial") NavigationSvc.activeSettingsPage.value = null;
  }
}

class _SettingsPageState extends State<SettingsPage> with ThemeHelpers {
  String searchQuery = "";
  final _paneObserver = _SettingsPaneObserver();

  List<Widget> _getSettingsItemList(BuildContext context) {
    return buildSettingItemList(
      context: context,
      searchQuery: searchQuery,
      tileColor: tileColor,
      samsung: samsung,
      iOS: iOS,
      material: material,
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      ns: NavigationSvc,
    );
  }

  @override
  void initState() {
    super.initState();

    if (showAltLayoutContextless) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        NavigationSvc.pushAndRemoveSettingsUntil(
          context,
          widget.initialPage ?? ServerManagementPanel(),
          (route) => route.isFirst,
        );
      });
    } else if (widget.initialPage != null) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        NavigationSvc.pushSettings(
          context,
          widget.initialPage!,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!showAltLayout && NavigationSvc.activeSettingsPage.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => NavigationSvc.activeSettingsPage.value = null);
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Actions(
          actions: {
            GoBackIntent: GoBackAction(context),
          },
          child: Obx(() => Container(
                color: context.theme.colorScheme.surface.themeOpacity(context),
                child: TabletModeWrapper(
                  initialRatio: 0.4,
                  minRatio: kIsDesktop || kIsWeb ? 0.2 : 0.33,
                  maxRatio: 0.5,
                  allowResize: true,
                  left: SettingsScaffold(
                    title: "Settings",
                    initialHeader: kIsWeb ? "Server & Message Management" : null,
                    iosSubtitle: iosSubtitle,
                    materialSubtitle: materialSubtitle,
                    tileColor: tileColor,
                    headerColor: headerColor,
                    bodySlivers: [
                      SliverList(
                        delegate: SliverChildListDelegate([
                          SettingsSearchBar(
                            iOS: iOS,
                            tileColor: tileColor,
                            onChanged: (value) {
                              setState(() {
                                searchQuery = value.trim().toLowerCase();
                              });
                            },
                          ),
                          ...(() {
                            final lowerQuery = searchQuery;
                            final settingsItemList = _getSettingsItemList(context);

                            // Build widgets list dynamically
                            final List<Widget> widgets = [];

                            for (int i = 0; i < settingsItemList.length; i++) {
                              final item = settingsItemList[i];
                              if (item is SearchableSettingItem) {
                                // Flat item (SearchableSettingItem)
                                final titleMatches = item.title.toLowerCase().contains(lowerQuery);
                                final tagMatches = item.searchTags.any(
                                  (tag) => tag.toLowerCase().contains(lowerQuery),
                                );

                                // Check if this is a header (contains SettingsHeader widget)
                                final isHeader = item.child.runtimeType.toString().contains('SettingsHeader');

                                // If it's a header and we're searching, check if the next section has matches
                                bool shouldShowHeader = true;
                                if (isHeader && searchQuery.isNotEmpty && i + 1 < settingsItemList.length) {
                                  final nextItem = settingsItemList[i + 1];
                                  if (nextItem is SettingsSection && nextItem.searchableSettingsItems != null) {
                                    // Only show header if the section has matching items
                                    shouldShowHeader = nextItem.searchableSettingsItems!.any((childItem) {
                                      final childTitleMatches = childItem.title.toLowerCase().contains(lowerQuery);
                                      final childTagMatches = childItem.searchTags.any(
                                        (tag) => tag.toLowerCase().contains(lowerQuery),
                                      );
                                      return childTitleMatches || childTagMatches;
                                    });
                                  }
                                }

                                if (searchQuery.isEmpty || (shouldShowHeader && (titleMatches || tagMatches))) {
                                  widgets.add(item);

                                  if (searchQuery.isNotEmpty) {
                                    final matchingTags = item.searchTags.where(
                                      (tag) => tag.toLowerCase().contains(lowerQuery),
                                    );

                                    for (final tag in matchingTags) {
                                      widgets.add(SearchBreadcrumbTile(
                                        origin: item.title,
                                        destination: tag,
                                        onTap: item.onTap,
                                      ));
                                    }
                                  }
                                }
                              } else if (item is SettingsSection) {
                                // Section → recurse into children
                                final sectionWidgets = <Widget>[];

                                if (item.searchableSettingsItems != null) {
                                  final matchingItems = item.searchableSettingsItems!.where((childItem) {
                                    final titleMatches = childItem.title.toLowerCase().contains(lowerQuery);
                                    final tagMatches = childItem.searchTags.any(
                                      (tag) => tag.toLowerCase().contains(lowerQuery),
                                    );
                                    return titleMatches || tagMatches;
                                  }).toList();

                                  if (searchQuery.isEmpty) {
                                    // No search → show whole section
                                    sectionWidgets.add(item);
                                  } else if (matchingItems.isNotEmpty) {
                                    // If any children match → rebuild section with only matching children
                                    sectionWidgets.add(SettingsSection(
                                      backgroundColor: item.backgroundColor,
                                      searchableSettingsItems: matchingItems,
                                      children: null, // Only show matching searchable children
                                    ));

                                    // Add breadcrumbs for matching child tags
                                    for (final matchingItem in matchingItems) {
                                      final matchingTags = matchingItem.searchTags.where(
                                        (tag) => tag.toLowerCase().contains(lowerQuery),
                                      );

                                      for (final tag in matchingTags) {
                                        sectionWidgets.add(SearchBreadcrumbTile(
                                          origin: matchingItem.title,
                                          destination: tag,
                                          onTap: matchingItem.onTap,
                                        ));
                                      }
                                    }
                                  }
                                } else if (item.children != null && searchQuery.isEmpty) {
                                  // Section with non-searchable children → show if no search
                                  sectionWidgets.add(item);
                                }

                                // Add section content to main list
                                widgets.addAll(sectionWidgets);
                              } else {
                                // Other Widget → show only if no search
                                if (searchQuery.isEmpty) {
                                  widgets.add(item);
                                }
                              }
                            }

                            // If searching and no results → show EmptySearchResult
                            final visibleWidgetsCount = widgets.length;
                            if (searchQuery.isNotEmpty && visibleWidgetsCount <= 1) {
                              return [EmptySearchResult(searchQuery: searchQuery)];
                            }

                            return widgets;
                          })(),
                        ]),
                      ),
                    ],
                  ),
                  right: LayoutBuilder(builder: (context, constraints) {
                    NavigationSvc.maxWidthSettings = constraints.maxWidth;
                    return PopScope(
                      canPop: false,
                      onPopInvokedWithResult: <T>(bool _, T? _) async {
                        Get.until((route) {
                          if (route.settings.name == "initial") {
                            Get.back();
                          } else {
                            Get.back(id: 3);
                          }
                          return true;
                        }, id: 3);
                      },
                      child: Navigator(
                        key: Get.nestedKey(3),
                        observers: [_paneObserver],
                        onPopPage: (route, _) {
                          route.didPop(false);
                          return false;
                        },
                        pages: [
                          CupertinoPage(
                              name: "initial",
                              child: Scaffold(
                                  backgroundColor:
                                      SettingsSvc.settings.skin.value != Skins.iOS ? tileColor : headerColor,
                                  body: Center(
                                    child: Text("Select a settings page from the list",
                                        style: context.theme.textTheme.bodyLarge),
                                  ))),
                        ],
                      ),
                    );
                  }),
                ),
              ))),
    );
  }
}
