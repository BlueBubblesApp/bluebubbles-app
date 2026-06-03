import 'dart:async';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/conversation_text_field_local_controller.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:chunked_stream/chunked_stream.dart';
import 'package:file_picker/file_picker.dart' as pf;
import 'package:file_picker/file_picker.dart' hide PlatformFile;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:giphy_get/giphy_get.dart' as giphy;
import 'package:tenor_flutter/tenor_flutter.dart';
import 'package:universal_io/io.dart';

/// Left-side icon buttons in the conversation text field row:
/// add (+), GIF, emoji picker toggle, and location share.
///
/// All button logic is self-contained here; heavy async flows reference
/// [controller] and [localController] directly.
class TextFieldIconBar extends StatelessWidget {
  const TextFieldIconBar({
    super.key,
    required this.controller,
    required this.localController,
  });

  final ConversationViewController controller;
  final ConversationTextFieldLocalController localController;

  Chat get _chat => controller.chat;

  bool get _iOS => SettingsSvc.settings.skin.value == Skins.iOS;

  bool get _showAttachmentPicker => localController.showAttachmentPickerLocal.value;

  @override
  Widget build(BuildContext context) {
    final hasBackground = ChatsSvc.getChatState(controller.chat.guid)?.customBackgroundPath.value?.isNotEmpty == true;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: IconButton(
            style: IconButton.styleFrom(
              backgroundColor: hasBackground
                  ? context.theme.colorScheme.surfaceContainerHighest
                  : context.theme.colorScheme.outline.withValues(alpha: 0.2),
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              minimumSize: const Size(36, 36),
              fixedSize: const Size(36, 36),
            ),
            icon: Icon(
              Icons.add,
              color: context.theme.colorScheme.outline,
              size: 22,
            ),
            visualDensity: Platform.isAndroid ? VisualDensity.compact : null,
            onPressed: () async {
              if (kIsDesktop) {
                final res = await FilePicker.pickFiles(withReadStream: true, allowMultiple: true);
                if (res == null || res.files.isEmpty || res.files.first.readStream == null) return;
                for (pf.PlatformFile e in res.files) {
                  if (e.size / 1024000 > 1000) {
                    showSnackbar("Error", "This file is over 1 GB! Please compress it before sending.");
                    continue;
                  }
                  controller.pickedAttachments.add(PlatformFile(
                    path: e.path,
                    name: e.name,
                    size: e.size,
                    bytes: await readByteStream(e.readStream!),
                  ));
                }
              } else if (kIsWeb) {
                showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                          title: Text("What would you like to do?", style: context.theme.textTheme.titleLarge),
                          content: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                ListTile(
                                  title: Text("Upload file", style: Theme.of(context).textTheme.bodyLarge),
                                  onTap: () async {
                                    final res = await FilePicker.pickFiles(withData: true, allowMultiple: true);
                                    if (res == null || res.files.isEmpty || res.files.first.bytes == null) {
                                      return;
                                    }

                                    for (pf.PlatformFile e in res.files) {
                                      if (e.size / 1024000 > 1000) {
                                        showSnackbar(
                                            "Error", "This file is over 1 GB! Please compress it before sending.");
                                        continue;
                                      }
                                      controller.pickedAttachments.add(PlatformFile(
                                        path: null,
                                        name: e.name,
                                        size: e.size,
                                        bytes: e.bytes!,
                                      ));
                                    }
                                    Get.back();
                                  },
                                ),
                                ListTile(
                                  title: Text("Send location", style: Theme.of(context).textTheme.bodyLarge),
                                  onTap: () async {
                                    Share.location(_chat);
                                    Get.back();
                                  },
                                ),
                              ]),
                          backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
                        ));
              } else {
                if (!_showAttachmentPicker) {
                  controller.focusNode.unfocus();
                  controller.subjectFocusNode.unfocus();
                }
                localController.showAttachmentPickerLocal.value = !_showAttachmentPicker;
              }
            },
          ),
        ),
        if (!kIsWeb && !Platform.isAndroid)
          IconButton(
              icon: Icon(Icons.gif, color: context.theme.colorScheme.outline, size: 28),
              onPressed: () => _onGifTapped(context)),
        if (kIsDesktop || kIsWeb)
          IconButton(
            icon: Icon(_iOS ? CupertinoIcons.smiley_fill : Icons.emoji_emotions,
                color: context.theme.colorScheme.outline, size: 28),
            onPressed: () {
              controller.showEmojiPicker.value = !controller.showEmojiPicker.value;
              (controller.editing.lastOrNull?.controller.focusNode ?? controller.lastFocusedNode).requestFocus();
            },
          ),
        if (kIsDesktop && !Platform.isLinux)
          IconButton(
            icon: Icon(_iOS ? CupertinoIcons.location_solid : Icons.location_on_outlined,
                color: context.theme.colorScheme.outline, size: 28),
            onPressed: () async {
              await Share.location(_chat);
            },
          ),
      ],
    );
  }

  // ---------- GIF picker ----------

  String _resolveTenorKey() {
    final override = SettingsSvc.settings.tenorApiKeyOverride.value.trim();
    if (override.isNotEmpty) return override;
    try {
      return kIsWeb ? TENOR_API_KEY : (dotenv.maybeGet('TENOR_API_KEY') ?? '');
    } catch (_) {
      return '';
    }
  }

  String _resolveGiphyKey() {
    final override = SettingsSvc.settings.giphyApiKeyOverride.value.trim();
    if (override.isNotEmpty) return override;
    try {
      return kIsWeb ? '' : (dotenv.maybeGet('GIPHY_API_KEY') ?? '');
    } catch (_) {
      return '';
    }
  }

  Future<void> _onGifTapped(BuildContext context) async {
    const validProviders = ['tenor', 'giphy', 'none'];
    final raw = SettingsSvc.settings.gifProvider.value;
    final provider = validProviders.contains(raw) ? raw : 'tenor';
    if (provider == 'none') {
      showSnackbar('GIF picker disabled',
          'The GIF picker is turned off in settings. Enable Tenor or Giphy under Settings → Conversations → GIF Picker.');
      return;
    }
    final apiKey = provider == 'tenor' ? _resolveTenorKey() : _resolveGiphyKey();
    if (apiKey.isEmpty) {
      final providerName = provider == 'tenor' ? 'Tenor' : 'Giphy';
      showSnackbar(
        'GIF picker unavailable',
        'No $providerName API key is configured. Add one under Settings → Conversations → GIF Picker.',
      );
      return;
    }
    if (kIsDesktop || kIsWeb) {
      controller.showingOverlays = true;
    }
    try {
      ({String id, Uint8List bytes})? picked;
      if (provider == 'tenor') {
        picked = await _pickTenorGif(context, apiKey);
      } else {
        picked = await _pickGiphyGif(context, apiKey);
      }
      if (picked != null) {
        controller.pickedAttachments.add(PlatformFile(
          path: null,
          name: "${picked.id}.gif",
          size: picked.bytes.length,
          bytes: picked.bytes,
        ));
      }
    } finally {
      if (kIsDesktop || kIsWeb) {
        controller.showingOverlays = false;
      }
    }
  }

  Future<({String id, Uint8List bytes})?> _pickTenorGif(BuildContext context, String apiKey) async {
    final tenor = Tenor(apiKey: apiKey);
    final searchController = TextEditingController();
    final focus = FocusNode();
    final resultFuture = tenor.showAsBottomSheet(
      maxExtent: 0.8,
      minExtent: 0.5,
      debounce: const Duration(seconds: 1),
      context: context,
      searchFieldController: searchController,
      searchFieldWidget: Padding(
        padding: const EdgeInsets.all(8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            TextField(
              focusNode: focus,
              controller: searchController,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(width: 0, style: BorderStyle.none),
                ),
                contentPadding: const EdgeInsets.fromLTRB(28, 5, 32, 7),
                filled: true,
                hintStyle: const TenorSearchFieldStyle().hintStyle,
                hintText: "Search Tenor",
                isCollapsed: true,
                isDense: true,
              ),
              style: context.theme.textTheme.bodyMedium!,
            ),
            const Positioned(
              left: 4,
              child: Icon(Icons.search, color: Color(0xFF8A8A86), size: 22),
            ),
          ],
        ),
      ),
      style: TenorStyle(
        color: context.theme.colorScheme.surfaceContainerHighest,
        attributionStyle: TenorAttributionStyle(brightnes: context.theme.brightness),
        tabBarStyle: TenorTabBarStyle(
          decoration: BoxDecoration(
              color: context.theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
          indicator: BoxDecoration(
            color: context.theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          labelColor: context.theme.colorScheme.onSurface,
          unselectedLabelColor: context.theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
    focus.requestFocus();
    final result = await resultFuture;
    final selectedGif = result?.media.tinyGif ?? result?.media.tinyGifTransparent;
    if (result == null || selectedGif == null) return null;
    final response = await HttpSvc.downloadFromUrl(selectedGif.url);
    if (response.statusCode != 200) return null;
    try {
      return (id: result.id, bytes: response.data as Uint8List);
    } catch (_) {
      return null;
    }
  }

  Future<({String id, Uint8List bytes})?> _pickGiphyGif(BuildContext context, String apiKey) async {
    final result = await giphy.GiphyGet.getGif(
      context: context,
      apiKey: apiKey,
      lang: giphy.GiphyLanguage.english,
      tabColor: context.theme.colorScheme.primary,
    );
    if (result == null) return null;
    final url = result.images?.downsized?.url ??
        result.images?.fixedHeightSmall?.url ??
        result.images?.fixedHeight?.url ??
        result.images?.original?.url;
    if (url == null || url.isEmpty) return null;
    final response = await HttpSvc.downloadFromUrl(url);
    if (response.statusCode != 200) return null;
    try {
      return (id: result.id ?? 'giphy', bytes: response.data as Uint8List);
    } catch (_) {
      return null;
    }
  }
}
