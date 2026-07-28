import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Two-column legend grid — every entry's dot and label start at the same
/// indent per column (a `Wrap` staggers them based on each label's width).
/// Capped to 4 rows tall and vertically scrollable beyond that so a large
/// group's legend doesn't push the rest of the page down. Shared by the
/// Overview balance bar and the Engagement balance-drift chart so every legend
/// in Chat Stats looks the same.
class LegendGrid extends StatelessWidget {
  const LegendGrid({super.key, required this.items});

  final List<({String label, Color color})> items;

  static const int _columns = 2;
  static const double _rowHeight = 26.0;
  static const int _maxVisibleRows = 4;

  @override
  Widget build(BuildContext context) {
    final rowCount = (items.length / _columns).ceil();
    final maxHeight = _rowHeight * (rowCount < _maxVisibleRows ? rowCount : _maxVisibleRows);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        child: Column(
          children: [
            for (var i = 0; i < items.length; i += _columns)
              SizedBox(
                height: _rowHeight,
                child: Row(
                  children: [
                    for (var col = 0; col < _columns; col++)
                      Expanded(
                        child: i + col < items.length ? _entry(context, items[i + col]) : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _entry(BuildContext context, ({String label, Color color}) item) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Row(
        children: [
          Container(
            width: 10.0,
            height: 10.0,
            decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6.0),
          Expanded(
            child: Text(
              item.label,
              style: context.theme.textTheme.labelSmall?.copyWith(color: context.theme.colorScheme.outline),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
