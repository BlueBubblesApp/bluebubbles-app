import 'package:bluebubbles/app/state/handle_state.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

class ContactAvatarWidget extends StatefulWidget {
  const ContactAvatarWidget(
      {super.key,
      this.size,
      this.fontSize,
      this.borderThickness = 2.0,
      this.editable = true,
      this.handle,
      this.contact,
      this.scaleSize = true,
      this.preferHighResAvatar = false,
      this.padding = EdgeInsets.zero});

  /// Canonical decode size for avatar images. Every avatar usage shares one
  /// ImageCache entry per file regardless of on-screen size — one decode per
  /// contact and a much higher cache-hit rate. The conversation list warm-up
  /// must use identical ResizeImage params for its precached entry to be hit.
  static const int avatarDecodeSize = 256;

  final Handle? handle;
  final ContactV2? contact;
  final double? size;
  final double? fontSize;
  final double borderThickness;
  final bool editable;
  final bool scaleSize;
  final bool preferHighResAvatar;
  final EdgeInsets padding;

  @override
  State<ContactAvatarWidget> createState() => _ContactAvatarWidgetState();
}

class _ContactAvatarWidgetState extends State<ContactAvatarWidget> with ThemeHelpers {
  ContactV2? get contactV2 => widget.contact ?? widget.handle?.contactsV2.firstOrNull;
  late final String keyPrefix = widget.handle?.address ?? randomString(8);

  HandleState? _handleState;

  @override
  void initState() {
    super.initState();
    if (widget.handle?.id != null) {
      _handleState = HandleSvc.getOrCreateHandleState(widget.handle!);
    }
  }

  @override
  void didUpdateWidget(ContactAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.handle?.id != widget.handle?.id) {
      _handleState = widget.handle?.id != null ? HandleSvc.getOrCreateHandleState(widget.handle!) : null;
    }
  }

  void onAvatarTap() async {
    final isIOS = SettingsSvc.settings.skin.value == Skins.iOS;
    if (isIOS && !SettingsSvc.settings.colorfulAvatars.value && !SettingsSvc.settings.colorfulBubbles.value) return;

    bool didReset = false;
    final Color color = await showColorPickerDialog(
      context,
      widget.handle?.color != null ? HexColor(widget.handle!.color!) : toColorGradient(widget.handle!.address)[0],
      title: SizedBox(
          width: NavigationSvc.width(context) - 112,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Choose a Color', style: context.theme.textTheme.titleLarge),
            TextButton(
              onPressed: () async {
                didReset = true;
                Navigator.of(context, rootNavigator: true).pop();
                widget.handle!.color = null;
                await widget.handle!.saveAsync(updateColor: true);
                // Notify ContactServiceV2 that this handle was updated
                ContactsSvcV2.notifyHandlesUpdated([widget.handle!.id!]);
              },
              child: const Text("RESET"),
            )
          ])),
      width: 40,
      height: 40,
      spacing: 0,
      runSpacing: 0,
      borderRadius: 0,
      wheelDiameter: 165,
      enableOpacity: false,
      showColorCode: true,
      colorCodeHasColor: true,
      backgroundColor: context.theme.dialogTheme.backgroundColor ?? context.theme.colorScheme.surfaceContainerHighest,
      barrierColor: context.theme.dialogTheme.barrierColor ?? context.theme.colorScheme.shadow.withValues(alpha: 0.6),
      pickersEnabled: <ColorPickerType, bool>{
        ColorPickerType.wheel: true,
      },
      copyPasteBehavior: const ColorPickerCopyPasteBehavior(
        parseShortHexCode: true,
      ),
      actionButtons: const ColorPickerActionButtons(
        dialogActionButtons: true,
      ),
      constraints: BoxConstraints(
          minHeight: 480, minWidth: NavigationSvc.width(context) - 70, maxWidth: NavigationSvc.width(context) - 70),
    );

    if (didReset) return;

    // Check if the color is the same as the real gradient, and if so, set it to null
    // Because it is not custom, then just use the regular gradient
    List gradient = toColorGradient(widget.handle?.address ?? "");
    if (!isNullOrEmpty(gradient) && gradient[0] == color) {
      widget.handle!.color = null;
    } else {
      widget.handle!.color = color.value.toRadixString(16);
    }

    await widget.handle!.saveAsync(updateColor: true);
    // Notify ContactServiceV2 that this handle was updated
    ContactsSvcV2.notifyHandlesUpdated([widget.handle!.id!]);
  }

  /// Shared fallback for the avatar circle: initials when available, otherwise
  /// a generic person icon. Used by the no-avatar branch, while an avatar image
  /// is still decoding (frameBuilder), and when the image file fails to load.
  Widget _buildInitialsOrIcon(double size, bool iOS, String? initials) {
    if (!isNullOrEmpty(initials)) {
      return SizedBox(
        width: size,
        child: Text(
          initials!,
          key: Key("$keyPrefix-avatar-text"),
          style: TextStyle(
            fontSize: size * 0.5,
            height: 1.0,
            leadingDistribution: TextLeadingDistribution.even,
            color: material ? context.theme.colorScheme.surface : Colors.white,
          ),
          textAlign: TextAlign.center,
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 1),
      child: Icon(
        iOS ? CupertinoIcons.person_fill : Icons.person,
        color: material ? context.theme.colorScheme.surface : Colors.white,
        key: Key("$keyPrefix-avatar-icon"),
        size: size / 2 * (material ? 1.25 : 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tileColor = ThemeSvc.inDarkMode(context)
        ? context.theme.colorScheme.surfaceContainerHighest
        : context.theme.colorScheme.surface;

    // Build once with all reactive values in outer Obx
    return Obx(() {
      final size =
          ((widget.size ?? 40) * (widget.scaleSize ? SettingsSvc.settings.avatarScale.value : 1)).roundToDouble();
      // Read from HandleState reactively so Obx rebuilds on contact sync.
      final colorStr = _handleState?.color.value;
      final colors = colorStr != null
          ? [HexColor(colorStr).lightenAmount(0.02), HexColor(colorStr)]
          : toColorGradient(widget.handle?.address);
      final cachedAvatarPath = _handleState?.avatarPath.value ?? contactV2?.avatarPath;
      final cachedInitials = _handleState?.initials.value ?? contactV2?.initials ?? widget.handle?.initials;
      final hideContactInfo = SettingsSvc.settings.redactedMode.value && SettingsSvc.settings.hideContactInfo.value;
      final genAvatars = SettingsSvc.settings.redactedMode.value && SettingsSvc.settings.generateFakeAvatars.value;
      final iOS = SettingsSvc.settings.skin.value == Skins.iOS;
      final colorfulAvatars = !iOS ||
          SettingsSvc.settings.colorfulAvatars.value ||
          (SettingsSvc.settings.skin.value == Skins.Material && ThemeSvc.isAnyMaterialYouSelected);
      final userAvatarPath = SettingsSvc.settings.userAvatarPath.value;

      return Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          splashColor: Colors.black,
          onTap: (!widget.editable || (!kIsDesktop && widget.handle == null && contactV2 == null))
              ? null
              : () async {
                  if (kIsDesktop) {
                    onAvatarTap();
                  } else if (contactV2 != null && contactV2!.isNative) {
                    try {
                      await MethodChannelSvc.actions.viewContactForm(nativeContactId: contactV2!.nativeContactId);
                    } catch (e, s) {
                      Logger.error("Failed to find contact on device", error: e, trace: s);
                      showSnackbar("Error", "Failed to find contact on device!");
                    }
                  } else if (widget.handle != null) {
                    await MethodChannelSvc.actions.openContactForm(
                      address: widget.handle!.address,
                      isEmail: widget.handle!.address.isEmail,
                    );
                  }
                },
          onLongPress: kIsDesktop || !widget.editable || widget.handle == null ? null : onAvatarTap,
          child: Container(
            key: Key("$keyPrefix-avatar-container"),
            width: size,
            height: size,
            padding: widget.padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  !colorfulAvatars
                      ? (ThemeSvc.inDarkMode(context) ? HexColor("8A8686") : HexColor("B8B4B4"))
                      : (iOS ? colors[1] : colors[0]),
                  !colorfulAvatars
                      ? (ThemeSvc.inDarkMode(context) ? HexColor("6B6868") : HexColor("928E8E"))
                      : colors[0],
                ],
                stops: [0.3, 0.9],
              ),
              border: Border.all(
                  color: iOS || SettingsSvc.settings.skin.value == Skins.Samsung
                      ? tileColor
                      : context.theme.colorScheme.surface,
                  width: widget.borderThickness,
                  strokeAlign: BorderSide.strokeAlignOutside),
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: () {
              // Reactive values already computed above in Obx scope.
              final contactV2Avatar = cachedAvatarPath;

              if (!hideContactInfo && widget.handle == null && userAvatarPath != null) {
                dynamic file = File(userAvatarPath);
                return CircleAvatar(
                  key: ValueKey(userAvatarPath),
                  radius: size / 2,
                  backgroundImage: Image.file(file).image,
                  backgroundColor: Colors.transparent,
                );
              } else if (!hideContactInfo && !genAvatars && contactV2Avatar != null) {
                final initials = cachedInitials?.substring(0, iOS ? null : 1);
                // Use ContactV2 avatar (from file path)
                return SizedBox.expand(
                  child: Image.file(
                    File(contactV2Avatar),
                    cacheHeight: ContactAvatarWidget.avatarDecodeSize,
                    cacheWidth: ContactAvatarWidget.avatarDecodeSize,
                    // Bilinear so the canonical 256px decode downscales cleanly
                    // to the small on-screen sizes (nearest-neighbor aliases).
                    filterQuality: FilterQuality.low,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                      if (wasSynchronouslyLoaded || frame != null) return child;
                      // Decode still in flight (cold image cache) — show the
                      // initials/icon fallback instead of a blank gradient circle.
                      return Center(child: _buildInitialsOrIcon(size, iOS, initials));
                    },
                    errorBuilder: (context, error, stackTrace) {
                      // If file doesn't exist, show initials instead
                      return Center(child: _buildInitialsOrIcon(size, iOS, initials));
                    },
                  ),
                );
              } else if (isNullOrEmpty(contactV2Avatar) || hideContactInfo || genAvatars) {
                // Use reactive initials from HandleState
                String? initials = cachedInitials?.substring(0, iOS ? null : 1);
                if (!isNullOrEmpty(initials) && !hideContactInfo && !genAvatars) {
                  return _buildInitialsOrIcon(size, iOS, initials);
                } else if (genAvatars && widget.handle?.fakeAvatar != null) {
                  return widget.handle!.fakeAvatar;
                } else if (genAvatars && contactV2?.fakeAvatar != null) {
                  return contactV2!.fakeAvatar;
                } else {
                  return _buildInitialsOrIcon(size, iOS, null);
                }
              }
            }(),
          ),
        ),
      );
    });
  }
}
