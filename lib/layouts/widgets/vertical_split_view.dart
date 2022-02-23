import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/layouts/titlebar_wrapper.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class VerticalSplitView extends StatefulWidget {
  final Widget left;
  final Widget right;
  final double initialRatio;
  final double dividerWidth;
  final double minRatio;
  final double maxRatio;
  final bool allowResize;

  const VerticalSplitView(
      {Key? key,
        required this.left,
        required this.right,
        this.initialRatio = 0.5,
        this.allowResize = true,
        this.dividerWidth = 7.0,
        this.minRatio = 0,
        this.maxRatio = 0})
      : assert(initialRatio >= 0),
        assert(initialRatio <= 1),
        super(key: key);

  @override
  _VerticalSplitViewState createState() => _VerticalSplitViewState();
}

class _VerticalSplitViewState extends State<VerticalSplitView> {
  //from 0-1
  late final RxDouble _ratio;
  double? _maxWidth;

  get _width1 => _ratio * _maxWidth!;

  get _width2 => (1 - _ratio.value) * _maxWidth!;

  @override
  void initState() {
    super.initState();
    _ratio = RxDouble(prefs.getDouble('splitRatio') ?? widget.initialRatio);
    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!event.containsKey("type")) return;

      if (event["type"] == 'split-refresh' && mounted) {
        _ratio.value = prefs.getDouble('splitRatio') ?? _ratio.value;
        setState(() {});
      }
    });
    debounce<double>(_ratio, (val) {
      prefs.setDouble('splitRatio', val);
      EventDispatcher().emit('split-refresh', null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, BoxConstraints constraints) {
      assert(_ratio <= 1);
      assert(_ratio >= 0);
      _maxWidth ??= constraints.maxWidth - widget.dividerWidth;
      if (_maxWidth != constraints.maxWidth) {
        _maxWidth = constraints.maxWidth - widget.dividerWidth;
      }

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
                      color: Theme.of(context).colorScheme.secondary,
                      child: SizedBox(
                        width: widget.dividerWidth,
                        height: constraints.maxHeight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(height: 4, width: 4, decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              color: Theme.of(context).textTheme.subtitle1?.color,
                            )),
                            SizedBox(height: 20,),
                            Container(height: 4, width: 4, decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              color: Theme.of(context).textTheme.subtitle1?.color,
                            )),
                            SizedBox(height: 20,),
                            Container(height: 4, width: 4, decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              color: Theme.of(context).textTheme.subtitle1?.color,
                            )),
                          ],
                        ),
                      )),
                  onPanUpdate: (DragUpdateDetails details) {
                    _ratio.value = (_ratio.value + (details.delta.dx / _maxWidth!)).clamp(widget.minRatio, widget.maxRatio);
                    CustomNavigator.listener.refresh();
                  },
                ),
              ) : SizedBox(
                width: widget.dividerWidth,
                height: constraints.maxHeight,
                child: Container(color: Theme.of(context).colorScheme.secondary)
              ),
              SizedBox(
                width: _width2,
                child: widget.right,
              ),
            ],
          ),
        )),
      );
    });
  }
}