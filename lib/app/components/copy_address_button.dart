import 'dart:async';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Copies [address]; the icon briefly turns into a check mark so the click has visible feedback on every
/// platform. Styled to match the menu button beside it on participant tiles for each skin.
class CopyAddressButton extends StatefulWidget {
  const CopyAddressButton({super.key, required this.address});

  final String address;

  @override
  State<CopyAddressButton> createState() => _CopyAddressButtonState();
}

class _CopyAddressButtonState extends State<CopyAddressButton> {
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.address));
    showCopiedToast("Address copied to clipboard");
    _resetTimer?.cancel();
    setState(() => _resetTimer = Timer(const Duration(milliseconds: 1500), () {
          if (mounted) setState(() => _resetTimer = null);
        }));
  }

  @override
  Widget build(BuildContext context) {
    final iOS = SettingsSvc.settings.skin.value == Skins.iOS;
    final copied = _resetTimer != null;
    final icon = copied
        ? (iOS ? CupertinoIcons.checkmark : Icons.check)
        : (iOS ? CupertinoIcons.doc_on_doc : Icons.copy_outlined);
    return Tooltip(
      message: copied ? "Copied" : "Copy address",
      child: ClipOval(
        child: Material(
          color: iOS ? context.theme.colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
          child: InkWell(
            onTap: _copy,
            child: SizedBox(
              width: iOS ? 30 : 32,
              height: iOS ? 30 : 32,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  icon,
                  key: ValueKey(copied),
                  color: iOS || copied ? context.theme.colorScheme.primary : context.theme.colorScheme.onSurfaceVariant,
                  size: iOS ? 16 : 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
