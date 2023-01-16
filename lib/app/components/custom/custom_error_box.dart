import 'dart:ui' as ui show Paragraph, ParagraphBuilder, ParagraphConstraints, ParagraphStyle, TextStyle;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CustomErrorWidget extends LeafRenderObjectWidget {
  /// Creates a widget that displays the given exception.
  ///
  /// The message will be the stringification of the given exception, unless
  /// computing that value itself throws an exception, in which case it will
  /// be the string "Error".
  ///
  /// If this object is inspected from an IDE or the devtools, and the original
  /// exception is a [FlutterError] object, the original exception itself will
  /// be shown in the inspection output.
  CustomErrorWidget(Object exception)
      : message = _stringify(exception),
        _flutterError = exception is FlutterError ? exception : null,
        super(key: UniqueKey());

  /// Creates a widget that displays the given error message.
  ///
  /// An explicit [FlutterError] can be provided to be reported to inspection
  /// tools. It need not match the message.
  CustomErrorWidget.withDetails({ this.message = '', FlutterError? error })
      : _flutterError = error,
        super(key: UniqueKey());

  /// The configurable factory for [CustomErrorWidget].
  ///
  /// When an error occurs while building a widget, the broken widget is
  /// replaced by the widget returned by this function. By default, an
  /// [CustomErrorWidget] is returned.
  ///
  /// The system is typically in an unstable state when this function is called.
  /// An exception has just been thrown in the middle of build (and possibly
  /// layout), so surrounding widgets and render objects may be in a rather
  /// fragile state. The framework itself (especially the [BuildOwner]) may also
  /// be confused, and additional exceptions are quite likely to be thrown.
  ///
  /// Because of this, it is highly recommended that the widget returned from
  /// this function perform the least amount of work possible. A
  /// [LeafRenderObjectWidget] is the best choice, especially one that
  /// corresponds to a [RenderBox] that can handle the most absurd of incoming
  /// constraints. The default constructor maps to a [RenderErrorBox].
  ///
  /// The default behavior is to show the exception's message in debug mode,
  /// and to show nothing but a gray background in release builds.
  ///
  /// See also:
  ///
  ///  * [FlutterError.onError], which is typically called with the same
  ///    [FlutterErrorDetails] object immediately prior to this callback being
  ///    invoked, and which can also be configured to control how errors are
  ///    reported.
  ///  * <https://flutter.dev/docs/testing/errors>, more information about error
  ///    handling in Flutter.
  static ErrorWidgetBuilder builder = _defaultErrorWidgetBuilder;

  static Widget _defaultErrorWidgetBuilder(FlutterErrorDetails details) {
    String message = '';
    assert(() {
      message = '${_stringify(details.exception)}\nSee also: https://flutter.dev/docs/testing/errors';
      return true;
    }());
    final Object exception = details.exception;
    return CustomErrorWidget.withDetails(message: message, error: exception is FlutterError ? exception : null);
  }

  static String _stringify(Object? exception) {
    try {
      return exception.toString();
    } catch (error) {
      // If we get here, it means things have really gone off the rails, and we're better
      // off just returning a simple string and letting the developer find out what the
      // root cause of all their problems are by looking at the console logs.
    }
    return 'Error';
  }

  /// The message to display.
  final String message;
  final FlutterError? _flutterError;

  @override
  RenderBox createRenderObject(BuildContext context) => RenderErrorBox(message);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    if (_flutterError == null) {
      properties.add(StringProperty('message', message, quoted: false));
    } else {
      properties.add(_flutterError!.toDiagnosticsNode(style: DiagnosticsTreeStyle.whitespace));
    }
  }
}

class RenderErrorBox extends RenderBox {
  /// Creates a RenderErrorBox render object.
  ///
  /// A message can optionally be provided. If a message is provided, an attempt
  /// will be made to render the message when the box paints.
  RenderErrorBox([ this.message = '' ]) {
    try {
      if (message != '') {
        // This class is intentionally doing things using the low-level
        // primitives to avoid depending on any subsystems that may have ended
        // up in an unstable state -- after all, this class is mainly used when
        // things have gone wrong.
        //
        // Generally, the much better way to draw text in a RenderObject is to
        // use the TextPainter class. If you're looking for code to crib from,
        // see the paragraph.dart file and the RenderParagraph class.
        final ui.ParagraphBuilder builder = ui.ParagraphBuilder(paragraphStyle);
        builder.pushStyle(textStyle);
        builder.addText(message);
        _paragraph = builder.build();
      } else {
        _paragraph = null;
      }
    } catch (error) {
      // If an error happens here we're in a terrible state, so we really should
      // just forget about it and let the developer deal with the already-reported
      // errors. It's unlikely that these errors are going to help with that.
    }
  }

  /// The message to attempt to display at paint time.
  final String message;

  late final ui.Paragraph? _paragraph;

  @override
  double computeMaxIntrinsicWidth(double height) {
    return 300;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return 100;
  }

  @override
  bool get sizedByParent => true;

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.constrain(const Size(300, 100));
  }

  /// The distance to place around the text.
  ///
  /// This is intended to ensure that if the [RenderErrorBox] is placed at the top left
  /// of the screen, under the system's status bar, the error text is still visible in
  /// the area below the status bar.
  ///
  /// The padding is ignored if the error box is smaller than the padding.
  ///
  /// See also:
  ///
  ///  * [minimumWidth], which controls how wide the box must be before the
  ///    horizontal padding is applied.
  static EdgeInsets padding = const EdgeInsets.fromLTRB(64.0, 96.0, 64.0, 12.0);

  /// The width below which the horizontal padding is not applied.
  ///
  /// If the left and right padding would reduce the available width to less than
  /// this value, then the text is rendered flush with the left edge.
  static double minimumWidth = 200.0;

  /// The color to use when painting the background of [RenderErrorBox] objects.
  ///
  /// Defaults to red in debug mode, a light gray otherwise.
  static Color backgroundColor = _initBackgroundColor();

  static Color _initBackgroundColor() {
    Color result = const Color(0xF0C0C0C0);
    assert(() {
      result = const Color(0xF0900000);
      return true;
    }());
    return result;
  }

  /// The text style to use when painting [RenderErrorBox] objects.
  ///
  /// Defaults to a yellow monospace font in debug mode, and a dark gray
  /// sans-serif font otherwise.
  static ui.TextStyle textStyle = _initTextStyle();

  static ui.TextStyle _initTextStyle() {
    ui.TextStyle result = ui.TextStyle(
      color: const Color(0xFF303030),
      fontFamily: 'sans-serif',
      fontSize: 18.0,
    );
    assert(() {
      result = ui.TextStyle(
        color: const Color(0xFFFFFF66),
        fontFamily: 'monospace',
        fontSize: 14.0,
        fontWeight: FontWeight.bold,
      );
      return true;
    }());
    return result;
  }

  /// The paragraph style to use when painting [RenderErrorBox] objects.
  static ui.ParagraphStyle paragraphStyle = ui.ParagraphStyle(
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.left,
  );

  @override
  void paint(PaintingContext context, Offset offset) {
    try {
      context.canvas.drawRect(offset & size, Paint() .. color = backgroundColor);
      if (_paragraph != null) {
        double width = size.width;
        double left = 0.0;
        double top = 0.0;
        if (width > padding.left + minimumWidth + padding.right) {
          width -= padding.left + padding.right;
          left += padding.left;
        }
        _paragraph!.layout(ui.ParagraphConstraints(width: width));
        if (size.height > padding.top + _paragraph!.height + padding.bottom) {
          top += padding.top;
        }
        context.canvas.drawParagraph(_paragraph!, offset + Offset(left, top));
      }
    } catch (error) {
      // If an error happens here we're in a terrible state, so we really should
      // just forget about it and let the developer deal with the already-reported
      // errors. It's unlikely that these errors are going to help with that.
    }
  }
}