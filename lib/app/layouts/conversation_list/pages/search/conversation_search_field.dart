import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Bordered search field used on the global Search screen and in-chat attachment search.
class ConversationSearchField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String placeholder;
  final bool isSearching;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final EdgeInsetsGeometry padding;

  const ConversationSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder = 'Enter a search term...',
    this.isSearching = false,
    this.onChanged,
    this.onSubmitted,
    this.padding = const EdgeInsets.only(left: 15, right: 15, top: 5),
  });

  @override
  State<ConversationSearchField> createState() => _ConversationSearchFieldState();
}

class _ConversationSearchFieldState extends State<ConversationSearchField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final bool _ownsController;
  late final bool _ownsFocusNode;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _ownsFocusNode = widget.focusNode == null;
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  void _submit() => widget.onSubmitted?.call(_controller.text);

  @override
  Widget build(BuildContext context) {
    final iOS = SettingsSvc.settings.skin.value == Skins.iOS;

    return Padding(
      padding: widget.padding,
      child: CupertinoTextField(
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        onChanged: widget.onChanged,
        focusNode: _focusNode,
        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10),
        controller: _controller,
        placeholder: widget.placeholder,
        style: context.theme.textTheme.bodyLarge,
        placeholderStyle: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.outline),
        cursorColor: context.theme.colorScheme.primary,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.theme.colorScheme.primary),
        ),
        maxLines: 1,
        prefix: Padding(
          padding: const EdgeInsets.only(left: 15),
          child: Icon(
            iOS ? CupertinoIcons.search : Icons.search,
            color: context.theme.colorScheme.outline,
          ),
        ),
        suffix: Padding(
          padding: const EdgeInsets.only(right: 15),
          child: !widget.isSearching
              ? InkWell(
                  onTap: _submit,
                  child: Icon(Icons.arrow_forward, color: context.theme.colorScheme.primary),
                )
              : Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: iOS
                      ? Theme(
                          data: ThemeData(
                            cupertinoOverrideTheme: CupertinoThemeData(
                              brightness: ThemeData.estimateBrightnessForColor(context.theme.colorScheme.surface),
                            ),
                          ),
                          child: const CupertinoActivityIndicator(),
                        )
                      : SizedBox(
                          height: 20,
                          width: 20,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                            ),
                          ),
                        ),
                ),
        ),
        suffixMode: OverlayVisibilityMode.editing,
      ),
    );
  }
}
