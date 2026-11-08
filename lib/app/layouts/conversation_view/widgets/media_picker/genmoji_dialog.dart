import 'dart:async';

import 'package:bluebubbles/app/components/wallpaper/dynamic_wallpaper_view.dart';
import 'package:bluebubbles/app/components/wallpaper/theme_wallpaper_palette.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/genmoji.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Opens the Genmoji creator: the user describes a Genmoji, the server's Mac draws it with
/// Apple Intelligence, and the user discards it, draws another, or attaches it.
///
/// Resolves to the image to attach, or null when the user backs out. Only call this when
/// `ServerDetails.supportsGenmoji` is true — the routes are v2-only.
Future<GenmojiImage?> showGenmojiDialog(BuildContext context, {required bool isIMessage}) {
  return showDialog<GenmojiImage>(
    context: context,
    // A tap outside would throw away a generation in flight; leaving is always a button.
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => GenmojiDialog(isIMessage: isIMessage),
  );
}

enum _GenmojiPhase { checking, unavailable, prompt, generating, result, failed }

class GenmojiDialog extends StatefulWidget {
  const GenmojiDialog({super.key, required this.isIMessage});

  /// Seeds the nebula's colors from the chat's bubble color.
  final bool isIMessage;

  @override
  State<GenmojiDialog> createState() => _GenmojiDialogState();
}

class _GenmojiDialogState extends State<GenmojiDialog> with ThemeHelpers {
  final TextEditingController _promptController = TextEditingController();
  final FocusNode _promptFocus = FocusNode();

  _GenmojiPhase _phase = _GenmojiPhase.checking;
  int _maxLength = GenmojiSupport.defaultMaximumDescriptionLength;
  String? _message;
  bool _canRetryStatus = false;
  GenmojiImage? _image;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _promptController.addListener(_onPromptChanged);
    _checkStatus();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _promptController.removeListener(_onPromptChanged);
    _promptController.dispose();
    _promptFocus.dispose();
    super.dispose();
  }

  /// Rebuilds the actions so Generate enables/disables as the prompt fills and empties.
  void _onPromptChanged() {
    if (mounted) setState(() {});
  }

  bool get _hasPrompt => _promptController.text.trim().isNotEmpty;

  void _setPhase(_GenmojiPhase phase, {String? message, bool canRetryStatus = false}) {
    if (!mounted) return;
    setState(() {
      _phase = phase;
      _message = message;
      _canRetryStatus = canRetryStatus;
    });
  }

  /// Asks the Mac whether it can draw at all before offering the prompt, so a Mac that can't
  /// (too old, Apple Intelligence off, no subscription) says why up front.
  Future<void> _checkStatus() async {
    _setPhase(_GenmojiPhase.checking);
    try {
      final support = await HttpSvc.genmoji.status();
      if (!mounted) return;
      if (!support.available) {
        return _setPhase(
          _GenmojiPhase.unavailable,
          message: support.detail ?? "Genmoji can't be created on your server's Mac right now.",
        );
      }
      _maxLength = support.maximumDescriptionLength;
      _setPhase(_GenmojiPhase.prompt);
      _promptFocus.requestFocus();
    } on GenmojiException catch (e) {
      Logger.warn("Genmoji unavailable: ${e.reason ?? e.statusCode}", tag: 'Genmoji');
      _setPhase(_GenmojiPhase.unavailable, message: e.message);
    } catch (e, s) {
      Logger.error("Failed to check Genmoji support", error: e, trace: s, tag: 'Genmoji');
      _setPhase(
        _GenmojiPhase.unavailable,
        message: "Couldn't reach your server to check Genmoji support.",
        canRetryStatus: true,
      );
    }
  }

  Future<void> _generate() async {
    final description = _promptController.text.trim();
    if (description.isEmpty) return;

    _promptFocus.unfocus();
    final token = CancelToken();
    _cancelToken = token;
    _setPhase(_GenmojiPhase.generating);

    try {
      final images = await HttpSvc.genmoji.create(description, cancelToken: token);
      if (!mounted || token.isCancelled) return;
      if (images.isEmpty) {
        return _setPhase(_GenmojiPhase.failed, message: "No Genmoji came back. Try describing it differently.");
      }
      _image = images.first;
      _setPhase(_GenmojiPhase.result);
    } on GenmojiException catch (e) {
      Logger.warn("Genmoji refused: ${e.reason ?? e.statusCode}", tag: 'Genmoji');
      _setPhase(_GenmojiPhase.failed, message: e.message);
    } on DioException catch (e, s) {
      if (CancelToken.isCancel(e)) return;
      Logger.error("Genmoji request failed", error: e, trace: s, tag: 'Genmoji');
      _setPhase(_GenmojiPhase.failed, message: "Couldn't reach your server. Check your connection and try again.");
    } catch (e, s) {
      Logger.error("Genmoji request failed", error: e, trace: s, tag: 'Genmoji');
      _setPhase(_GenmojiPhase.failed, message: "Something went wrong creating your Genmoji.");
    } finally {
      if (identical(_cancelToken, token)) _cancelToken = null;
    }
  }

  void _stopGenerating() {
    _cancelToken?.cancel();
    _cancelToken = null;
    _setPhase(_image != null ? _GenmojiPhase.result : _GenmojiPhase.prompt);
  }

  void _close([GenmojiImage? result]) {
    _cancelToken?.cancel();
    Navigator.of(context).pop(result);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  List<({String label, VoidCallback? onPressed, bool isDefault, bool isDestructive})> get _actions {
    switch (_phase) {
      case _GenmojiPhase.checking:
        return [(label: "Cancel", onPressed: _close, isDefault: false, isDestructive: false)];
      case _GenmojiPhase.unavailable:
        return [
          (label: "Close", onPressed: _close, isDefault: !_canRetryStatus, isDestructive: false),
          if (_canRetryStatus) (label: "Retry", onPressed: _checkStatus, isDefault: true, isDestructive: false),
        ];
      case _GenmojiPhase.prompt:
        return [
          (label: "Cancel", onPressed: _close, isDefault: false, isDestructive: false),
          (label: "Generate", onPressed: _hasPrompt ? _generate : null, isDefault: true, isDestructive: false),
        ];
      case _GenmojiPhase.generating:
        return [(label: "Stop", onPressed: _stopGenerating, isDefault: false, isDestructive: false)];
      case _GenmojiPhase.failed:
        return [
          (label: "Cancel", onPressed: _close, isDefault: false, isDestructive: false),
          (label: "Try Again", onPressed: _hasPrompt ? _generate : null, isDefault: true, isDestructive: false),
        ];
      case _GenmojiPhase.result:
        return [
          (label: "Discard", onPressed: _close, isDefault: false, isDestructive: true),
          (label: "New", onPressed: _hasPrompt ? _generate : null, isDefault: false, isDestructive: false),
          (label: "Attach", onPressed: () => _close(_image), isDefault: true, isDestructive: false),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);

    if (iOS) {
      return CupertinoTheme(
        // Bridge Material brightness into the Cupertino color system (as showBBDialog does).
        data: CupertinoThemeData(brightness: Theme.of(context).brightness),
        child: CupertinoAlertDialog(
          title: const Text("Genmoji"),
          content: Material(type: MaterialType.transparency, child: content),
          actions: _actions
              .map(
                (a) => CupertinoDialogAction(
                  isDefaultAction: a.isDefault,
                  isDestructiveAction: a.isDestructive,
                  onPressed: a.onPressed,
                  child: Text(a.label),
                ),
              )
              .toList(),
        ),
      );
    }

    return AlertDialog(
      title: Text("Genmoji", style: context.theme.textTheme.titleLarge),
      backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 6),
      content: SizedBox(width: 300, child: content),
      actions: _actions
          .map(
            (a) => TextButton(
              onPressed: a.onPressed,
              child: Text(
                a.label,
                style: context.theme.textTheme.bodyLarge!.copyWith(
                  color: a.onPressed == null
                      ? context.theme.colorScheme.outline
                      : a.isDestructive
                      ? context.theme.colorScheme.error
                      : context.theme.colorScheme.primary,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildContent(BuildContext context) {
    final showPrompt = _phase != _GenmojiPhase.checking && _phase != _GenmojiPhase.unavailable;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: iOS ? 12 : 4),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: KeyedSubtree(key: ValueKey(_phase), child: _buildCanvas(context)),
                ),
              ),
            ),
          ),
        ),
        if (showPrompt) ...[const SizedBox(height: 14), _buildPromptField(context)],
      ],
    );
  }

  /// The square above the prompt: the nebula while drawing, the Genmoji once drawn, and a
  /// message in between.
  Widget _buildCanvas(BuildContext context) {
    final scheme = context.theme.colorScheme;
    switch (_phase) {
      case _GenmojiPhase.generating:
        return _GenmojiNebula(isIMessage: widget.isIMessage);
      case _GenmojiPhase.result:
        return ColoredBox(
          color: scheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Image.memory(_image!.png, fit: BoxFit.contain, gaplessPlayback: true),
          ),
        );
      case _GenmojiPhase.checking:
        return ColoredBox(
          color: scheme.surface,
          child: Center(child: iOS ? const CupertinoActivityIndicator() : const CircularProgressIndicator()),
        );
      case _GenmojiPhase.prompt:
        return _CanvasMessage(
          icon: Icons.auto_awesome_rounded,
          message: "Describe an emoji and your Mac will create it.",
          color: scheme.primary,
        );
      case _GenmojiPhase.unavailable:
      case _GenmojiPhase.failed:
        return _CanvasMessage(
          icon: Icons.error_outline_rounded,
          message: _message ?? "Something went wrong.",
          color: scheme.error,
        );
    }
  }

  Widget _buildPromptField(BuildContext context) {
    final enabled = _phase != _GenmojiPhase.generating;
    void onSubmitted(String _) {
      if (enabled && _hasPrompt) _generate();
    }

    if (iOS) {
      return CupertinoTextField(
        controller: _promptController,
        focusNode: _promptFocus,
        enabled: enabled,
        maxLength: _maxLength,
        minLines: 1,
        maxLines: 3,
        textInputAction: TextInputAction.done,
        textCapitalization: TextCapitalization.sentences,
        placeholder: "Describe a Genmoji",
        style: context.theme.textTheme.bodyLarge,
        onSubmitted: onSubmitted,
      );
    }

    return TextField(
      controller: _promptController,
      focusNode: _promptFocus,
      enabled: enabled,
      maxLength: _maxLength,
      minLines: 1,
      maxLines: 3,
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.sentences,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: "Describe a Genmoji",
        // The 500-character cap is a backstop, not something worth a counter under every prompt.
        counterText: "",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
      ),
    );
  }
}

class _CanvasMessage extends StatelessWidget {
  const _CanvasMessage({required this.icon, required this.message, required this.color});

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            // The server's refusal sentences can run to a few lines (e.g. `needs_app`), more than
            // the square holds at larger text scales — scroll rather than clip them.
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.onSurface),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "drawing" state: the Particles wallpaper's Nebula preset in the chat's theme colors,
/// run denser and faster than a wallpaper would be, under a pulsing sparkle.
class _GenmojiNebula extends StatefulWidget {
  const _GenmojiNebula({required this.isIMessage});

  final bool isIMessage;

  @override
  State<_GenmojiNebula> createState() => _GenmojiNebulaState();
}

class _GenmojiNebulaState extends State<_GenmojiNebula> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);
  Map<String, dynamic>? _config;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Built once per showing: the particle set is keyed on its config, so recomputing it on
    // every rebuild would restart the animation.
    _config ??= {
      'preset': 'nebula',
      'count': 30,
      'speed': 2.0,
      'colors': ThemeWallpaperPalette.fromContext(
        context,
        isIMessage: widget.isIMessage,
      ).take(4).map((c) => c.toARGB32()).toList(),
    };
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        DynamicWallpaperView(wallpaperId: 'particles', config: _config),
        Center(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_pulse.value);
              return Opacity(
                opacity: 0.55 + 0.45 * t,
                child: Transform.scale(scale: 0.9 + 0.2 * t, child: child),
              );
            },
            child: Icon(Icons.auto_awesome_rounded, size: 48, color: scheme.primary),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 14,
          child: Text(
            "Creating Genmoji…",
            textAlign: TextAlign.center,
            style: context.theme.textTheme.labelLarge!.copyWith(color: scheme.onSurface),
          ),
        ),
      ],
    );
  }
}
