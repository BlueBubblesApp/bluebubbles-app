import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TabletModeWrapper extends StatefulWidget {
  final Widget left;
  final Widget right;
  final double initialRatio;
  final double dividerWidth;
  final double minRatio;
  final double maxRatio;
  final bool allowResize;

  const TabletModeWrapper({Key? key,
    required this.left,
    required this.right,
    this.initialRatio = 0.5,
    this.allowResize = true,
    this.dividerWidth = 7.0,
    this.minRatio = 0,
    this.maxRatio = 0
  }) : assert(initialRatio >= 0),
        assert(initialRatio <= 1),
        super(key: key);

  @override
  State<TabletModeWrapper> createState() => _TabletModeWrapperState();
}

class _TabletModeWrapperState extends OptimizedState<TabletModeWrapper> {
  //from 0-1
  late final RxDouble _ratio;
  double? _maxWidth;

  get _width1 => _ratio * _maxWidth!;

  get _width2 => (1 - _ratio.value) * _maxWidth!;

  @override
  void initState() {
    super.initState();
    _ratio = RxDouble(ss.prefs.getDouble('splitRatio') ?? widget.initialRatio);
    eventDispatcher.stream.listen((event) {
      if (event.item1 == 'split-refresh') {
        _ratio.value = ss.prefs.getDouble('splitRatio') ?? _ratio.value;
        setState(() {});
      }
    });
    debounce<double>(_ratio, (val) {
      ss.prefs.setDouble('splitRatio', val);
      eventDispatcher.emit('split-refresh', null);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!showAltLayout) {
      return TitleBarWrapper(child: widget.left);
    }
    return LayoutBuilder(
      builder: (context, BoxConstraints constraints) {
        _maxWidth = constraints.maxWidth - widget.dividerWidth;
        return TitleBarWrapper(
          child: SizedBox(
            width: constraints.maxWidth,
            child: Obx(() => Row(
              children: <Widget>[
                SizedBox(
                  width: _width1,
                  child: widget.left,
                ),
                (widget.allowResize) ? MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    child: Container(
                      color: context.theme.colorScheme.properSurface,
                      width: widget.dividerWidth,
                      height: constraints.maxHeight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(height: 4, width: 4, decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            color: context.theme.colorScheme.properOnSurface,
                          )),
                          const SizedBox(height: 20),
                          Container(height: 4, width: 4, decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            color: context.theme.colorScheme.properOnSurface,
                          )),
                          const SizedBox(height: 20),
                          Container(height: 4, width: 4, decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            color: context.theme.colorScheme.properOnSurface,
                          )),
                        ],
                      ),
                    ),
                    onPanUpdate: (DragUpdateDetails details) {
                      _ratio.value = (_ratio.value + (details.delta.dx / _maxWidth!)).clamp(widget.minRatio, widget.maxRatio);
                      ns.listener.refresh();
                    },
                  ),
                ) : Container(
                    width: widget.dividerWidth,
                    height: constraints.maxHeight,
                    color: context.theme.colorScheme.properSurface
                ),
                SizedBox(
                  width: _width2,
                  child: widget.right,
                ),
              ],
            )),
          ),
        );
      },
    );
  }
}