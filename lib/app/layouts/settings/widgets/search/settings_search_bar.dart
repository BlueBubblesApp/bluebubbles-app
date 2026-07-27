import 'dart:async';

import 'package:bluebubbles/app/layouts/settings/widgets/search/settings_search_bar_ios.dart';
import 'package:flutter/material.dart';

class SettingsSearchBar extends StatefulWidget {
  final ValueChanged<String>? onChanged;
  final bool iOS;
  final Color? tileColor;

  const SettingsSearchBar({super.key, this.onChanged, required this.iOS, this.tileColor});

  @override
  State<SettingsSearchBar> createState() => _SettingsSearchBarState();
}

class _SettingsSearchBarState extends State<SettingsSearchBar> {
  String searchValue = '';
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;

  void _onSearchChanged(String query) {
    setState(() {
      searchValue = query.toLowerCase();
    });

    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      widget.onChanged?.call('');
      return;
    }

    if (query.trim().length < 3) return;

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      widget.onChanged?.call(searchValue);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SettingsSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // sync the controller text when widget changes
    _controller.text = searchValue;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
      child: widget.iOS
          ? SettingsSearchBariOS(
              // use cupertino search bar if iOS style
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _onSearchChanged,
            )
          : SearchBar(
              // material themed search bar
              controller: _controller,
              focusNode: _focusNode,
              backgroundColor: widget.tileColor != null ? WidgetStatePropertyAll(widget.tileColor) : null,
              hintText: 'Search Settings',
              hintStyle: MaterialStateProperty.all(
                TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.5),
                ),
              ),
              padding: const WidgetStatePropertyAll<EdgeInsets>(
                EdgeInsets.symmetric(horizontal: 16.0),
              ),
              elevation: const MaterialStatePropertyAll(1),
              onChanged: _onSearchChanged,
              leading: const Icon(Icons.search),
              trailing: <Widget>[
                if (searchValue.isNotEmpty)
                  Tooltip(
                    message: 'Clear search',
                    child: IconButton(
                      onPressed: () {
                        _debounceTimer?.cancel();
                        setState(() {
                          searchValue = '';
                          _controller.text = '';
                          _focusNode.unfocus();
                        });
                        widget.onChanged?.call('');
                      },
                      icon: const Icon(Icons.clear),
                    ),
                  ),
              ],
            ),
    );
  }
}
