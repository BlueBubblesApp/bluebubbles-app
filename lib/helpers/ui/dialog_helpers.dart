import 'package:bluebubbles/app/components/custom/custom_cupertino_alert_dialog.dart';
import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart' hide CupertinoAlertDialog, CupertinoDialogAction;
import 'package:flutter/material.dart';

/// A single action button for use in [showBBDialog].
class BBDialogAction {
  final String text;
  final VoidCallback? onPressed;

  /// iOS skin only — renders the button text in red (destructive style).
  final bool isDestructive;

  /// iOS skin only — renders the button text bold (default/primary action).
  final bool isDefault;

  /// Material/Samsung skin only — overrides the button text color.
  final Color? color;

  const BBDialogAction({
    required this.text,
    this.onPressed,
    this.isDestructive = false,
    this.isDefault = false,
    this.color,
  });
}

/// Shows a skin-aware dialog.
///
/// On the iOS skin this renders a [CupertinoAlertDialog]; on Material and
/// Samsung skins it renders a standard [AlertDialog].
///
/// Supply either [content] (a Widget) or [body] (a plain string) for the
/// dialog body — [content] takes precedence if both are provided.
///
/// [bodyTextAlign] controls the text alignment of the dialog body. It applies
/// directly to [body] and is also made available to [content] via a
/// [DefaultTextStyle] so custom content can opt in by inheriting it.
Future<T?> showBBDialog<T>({
  required BuildContext context,
  String? title,
  Widget? content,
  String? body,
  List<BBDialogAction> actions = const [],
  bool barrierDismissible = true,
  bool useRootNavigator = true,
  TextAlign? bodyTextAlign,
}) {
  final skin = SettingsSvc.settings.skin.value;
  final rawBodyWidget = content ?? (body != null ? Text(body, textAlign: bodyTextAlign) : null);
  final bodyWidget = bodyTextAlign != null && rawBodyWidget != null
      ? DefaultTextStyle.merge(textAlign: bodyTextAlign, child: rawBodyWidget)
      : rawBodyWidget;

  if (skin == Skins.iOS) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      useRootNavigator: useRootNavigator,
      builder: (ctx) => CupertinoTheme(
        // Bridge Material theme brightness into the Cupertino color system so
        // CupertinoDynamicColor.resolve picks the correct light/dark variants
        // for both the dialog background and the action-button backgrounds.
        data: CupertinoThemeData(brightness: Theme.of(ctx).brightness),
        child: CupertinoAlertDialog(
          backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
          title: title != null ? Text(title) : null,
          // Wrap in a transparent Material so that Material widgets (e.g.
          // TextField) embedded in custom content can find their ancestor.
          content: bodyWidget != null ? Material(type: MaterialType.transparency, child: bodyWidget) : null,
          actions: actions
              .map(
                (a) => CupertinoDialogAction(
                  isDestructiveAction: a.isDestructive,
                  isDefaultAction: a.isDefault,
                  onPressed: a.onPressed,
                  child: Text(a.text),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  // Material / Samsung
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    useRootNavigator: true,
    builder: (ctx) => AlertDialog(
      title: title != null ? Text(title, style: ctx.textTheme.titleLarge) : null,
      content: bodyWidget,
      backgroundColor: ctx.colorScheme.surfaceContainerHighest,
      actions: actions
          .map(
            (a) => TextButton(
              onPressed: a.onPressed,
              child: Text(
                a.text,
                style: ctx.textTheme.bodyLarge!.copyWith(
                  color: a.color ?? ctx.colorScheme.primary,
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
}

/// Convenience wrapper around [showBBDialog] for simple yes/no confirmation dialogs.
///
/// Prefer this over the deprecated [areYouSure] helper.
Future<void> showAreYouSure(
  BuildContext context, {
  Widget? content,
  String? title = "Are you sure?",
  String? noText = "No",
  String? yesText = "Yes",
  Color? noColor,
  Color? yesColor,
  TextAlign textAlign = TextAlign.center,
  required Function onNo,
  required Function onYes,
}) {
  return showBBDialog(
    context: context,
    title: title,
    content: content,
    bodyTextAlign: textAlign,
    actions: [
      BBDialogAction(
        text: noText ?? "No",
        color: noColor,
        onPressed: () => onNo.call(),
      ),
      BBDialogAction(
        text: yesText ?? "Yes",
        color: yesColor,
        isDefault: true,
        onPressed: () => onYes.call(),
      ),
    ],
  );
}

/// A single selectable option for [showBBListSelector].
class BBListSelectorOption<T> {
  final String label;
  final T value;

  /// iOS action-sheet style only — renders the option in red.
  final bool isDestructive;

  const BBListSelectorOption({
    required this.label,
    required this.value,
    this.isDestructive = false,
  });
}

/// Controls how [showBBListSelector] presents its options on the iOS skin.
/// Ignored on Material/Samsung, which always render as a scrollable list.
enum BBListSelectorIOSStyle {
  /// A bottom [CupertinoActionSheet] with one button per option — the
  /// standard iOS pattern for picking one of a short list of discrete
  /// choices (e.g. "Remind me in...").
  actionSheet,

  /// A scrolling [CupertinoPicker] wheel inside a modal with a Done/Cancel
  /// toolbar — the pattern iOS uses for date/time or continuous-value
  /// selection.
  wheel,
}

/// Shows a skin-aware single-selection list dialog.
///
/// On Material/Samsung this renders as a [showBBDialog] with [options] as a
/// scrollable list of tappable rows. On the iOS skin, [iosStyle] controls
/// whether it renders as a [CupertinoActionSheet] (default) or a scrolling
/// [CupertinoPicker] wheel.
Future<T?> showBBListSelector<T>({
  required BuildContext context,
  String? title,
  String? message,
  required List<BBListSelectorOption<T>> options,
  BBListSelectorIOSStyle iosStyle = BBListSelectorIOSStyle.actionSheet,
  String cancelText = "Cancel",
}) {
  final skin = SettingsSvc.settings.skin.value;

  if (skin == Skins.iOS) {
    return iosStyle == BBListSelectorIOSStyle.wheel
        ? _showCupertinoWheelSelector<T>(context, title: title, options: options, cancelText: cancelText)
        : _showCupertinoActionSheetSelector<T>(
            context,
            title: title,
            message: message,
            options: options,
            cancelText: cancelText,
          );
  }

  // Material / Samsung
  return showBBDialog<T>(
    context: context,
    title: title,
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(message)),
          ...options.map((option) {
            return ListTile(
              title: Text(
                option.label,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: option.isDestructive ? context.colorScheme.error : null,
                ),
              ),
              onTap: () => Navigator.of(context).pop(option.value),
            );
          }),
        ],
      ),
    ),
    actions: [
      BBDialogAction(text: cancelText, onPressed: () => Navigator.of(context).pop()),
    ],
  );
}

Future<T?> _showCupertinoActionSheetSelector<T>(
  BuildContext context, {
  String? title,
  String? message,
  required List<BBListSelectorOption<T>> options,
  required String cancelText,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (ctx) => CupertinoTheme(
      // Bridge Material theme brightness into the Cupertino color system so
      // CupertinoDynamicColor.resolve picks the correct light/dark variant
      // instead of falling back to the system platform brightness.
      data: CupertinoThemeData(brightness: Theme.of(ctx).brightness),
      child: CupertinoActionSheet(
        title: title != null ? Text(title) : null,
        message: message != null ? Text(message) : null,
        actions: options.map((option) {
          return CupertinoActionSheetAction(
            isDestructiveAction: option.isDestructive,
            onPressed: () => Navigator.of(ctx).pop(option.value),
            child: Text(option.label),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(cancelText),
        ),
      ),
    ),
  );
}

Future<T?> _showCupertinoWheelSelector<T>(
  BuildContext context, {
  String? title,
  required List<BBListSelectorOption<T>> options,
  required String cancelText,
}) {
  var selectedIndex = 0;
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (ctx) {
      // Bridge Material theme brightness into the Cupertino color system so
      // CupertinoDynamicColor.resolve (and CupertinoTheme.of() lookups below)
      // pick the correct light/dark variant instead of falling back to the
      // system platform brightness.
      final cupertinoTheme = CupertinoThemeData(brightness: Theme.of(ctx).brightness);
      return CupertinoTheme(
        data: cupertinoTheme,
        child: Container(
          height: 260,
          color: cupertinoTheme.scaffoldBackgroundColor,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(cancelText),
                  ),
                  if (title != null) Text(title, style: cupertinoTheme.textTheme.navTitleTextStyle),
                  CupertinoButton(
                    onPressed: () => Navigator.of(ctx).pop(options[selectedIndex].value),
                    child: const Text("Done"),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 36,
                  onSelectedItemChanged: (index) => selectedIndex = index,
                  children: options.map((o) => Center(child: Text(o.label))).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// A skin-aware dialog for showing the progress of a long-running operation.
///
/// Unlike [showBBDialog], this is a [Widget] rather than a one-shot show
/// function: callers typically rebuild it in place as progress advances
/// (e.g. inside an `Obx`, or after `setState`), so it needs to stay mounted
/// across content changes rather than being torn down and re-shown.
///
/// On iOS this renders as a [CupertinoAlertDialog] with an iOS-styled
/// progress indicator (a thin rounded bar when [progress] is non-null, or a
/// [CupertinoActivityIndicator] spinner when it's `null`/indeterminate). On
/// Material/Samsung it renders as a standard [AlertDialog] with a
/// [LinearProgressIndicator].
class BBProgressDialog extends StatelessWidget {
  const BBProgressDialog({
    super.key,
    required this.title,
    this.progress,
    this.body,
    this.actions = const [],
  });

  /// Dialog title. Update this as progress advances (e.g. "Syncing..." ->
  /// "Done syncing!").
  final String title;

  /// Progress value in `[0, 1]`, or `null` for an indeterminate state.
  /// Ignored when [body] is provided.
  final double? progress;

  /// Replaces the progress indicator entirely when non-null (e.g. to show
  /// an error message instead).
  final Widget? body;

  final List<BBDialogAction> actions;

  @override
  Widget build(BuildContext context) {
    final skin = SettingsSvc.settings.skin.value;

    if (skin == Skins.iOS) {
      return CupertinoTheme(
        data: CupertinoThemeData(brightness: Theme.of(context).brightness),
        child: CupertinoAlertDialog(
          backgroundColor: context.colorScheme.surfaceContainerHighest,
          title: Text(title),
          content: Material(
            type: MaterialType.transparency,
            child: body ?? _CupertinoProgressIndicator(value: progress),
          ),
          actions: actions
              .map(
                (a) => CupertinoDialogAction(
                  isDestructiveAction: a.isDestructive,
                  isDefaultAction: a.isDefault,
                  onPressed: a.onPressed,
                  child: Text(a.text),
                ),
              )
              .toList(),
        ),
      );
    }

    // Material / Samsung
    return AlertDialog(
      title: Text(title, style: context.textTheme.titleLarge),
      backgroundColor: context.colorScheme.surfaceContainerHighest,
      content: body ??
          SizedBox(
            height: 5,
            child: Center(
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: context.colorScheme.outline,
                valueColor: AlwaysStoppedAnimation<Color>(context.colorScheme.primary),
              ),
            ),
          ),
      actions: actions
          .map(
            (a) => TextButton(
              onPressed: a.onPressed,
              child: Text(
                a.text,
                style: context.textTheme.bodyLarge!.copyWith(color: a.color ?? context.colorScheme.primary),
              ),
            ),
          )
          .toList(),
    );
  }
}

/// An iOS-styled progress indicator for [BBProgressDialog]: a thin rounded
/// bar using Cupertino colors when [value] is non-null, or a native spinner
/// when it's `null` (indeterminate).
class _CupertinoProgressIndicator extends StatelessWidget {
  const _CupertinoProgressIndicator({this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: CupertinoActivityIndicator(),
      );
    }

    final activeColor = CupertinoTheme.of(context).primaryColor;
    final trackColor = CupertinoDynamicColor.resolve(CupertinoColors.systemFill, context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: SizedBox(
          height: 4,
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: trackColor,
            valueColor: AlwaysStoppedAnimation<Color>(activeColor),
          ),
        ),
      ),
    );
  }
}

// BuildContext extensions for convenient theme access inside this file
extension _ContextTheme on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
}
