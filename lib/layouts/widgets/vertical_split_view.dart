import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
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
        this.dividerWidth = 16.0,
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

      return SizedBox(
        width: constraints.maxWidth,
        child: Obx(() => Row(
          children: <Widget>[
            SizedBox(
              width: _width1,
              child: widget.left,
            ),
            (widget.allowResize) ? GestureDetector(
              behavior: HitTestBehavior.translucent,
              child: Container(
                  color: Theme.of(context).accentColor,
                  child: SizedBox(
                    width: widget.dividerWidth,
                    height: constraints.maxHeight,
                    child: Icon(Icons.drag_indicator, color: Theme.of(context).textTheme.subtitle1?.color, size: 10),
                  )),
              onPanUpdate: (DragUpdateDetails details) {
                _ratio.value = (_ratio.value + (details.delta.dx / _maxWidth!)).clamp(widget.minRatio, widget.maxRatio);
              },
            ) : SizedBox(
              width: widget.dividerWidth,
              height: constraints.maxHeight,
              child: Container(color: Theme.of(context).accentColor)
            ),
            SizedBox(
              width: _width2,
              child: widget.right,
            ),
          ],
        ),
      ));
    });
  }
}