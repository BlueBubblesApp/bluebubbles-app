# extended_text_field

[![pub package](https://img.shields.io/pub/v/extended_text_field.svg)](https://pub.dartlang.org/packages/extended_text_field) [![GitHub stars](https://img.shields.io/github/stars/fluttercandies/extended_text_field)](https://github.com/fluttercandies/extended_text_field/stargazers) [![GitHub forks](https://img.shields.io/github/forks/fluttercandies/extended_text_field)](https://github.com/fluttercandies/extended_text_field/network)  [![GitHub license](https://img.shields.io/github/license/fluttercandies/extended_text_field)](https://github.com/fluttercandies/extended_text_field/blob/master/LICENSE)  [![GitHub issues](https://img.shields.io/github/issues/fluttercandies/extended_text_field)](https://github.com/fluttercandies/extended_text_field/issues) <a target="_blank" href="https://jq.qq.com/?_wv=1027&k=5bcc0gy"><img border="0" src="https://pub.idqqimg.com/wpa/images/group.png" alt="flutter-candies" title="flutter-candies"></a>

Extended official text field to build special text like inline image, @somebody, custom background etc quickly.It also support to build custom seleciton toolbar and handles.

Language: [English](README.md) | [中文简体](README-ZH.md)

- [extended_text_field](#extendedtextfield)
  - [Limitation](#limitation)
  - [Speical Text](#speical-text)
    - [Create Speical Text](#create-speical-text)
    - [SpecialTextSpanBuilder](#specialtextspanbuilder)
  - [Image](#image)
    - [ImageSpan](#imagespan)
    - [Cache Image](#cache-image)
  - [TextSelectionControls](#textselectioncontrols)
  - [WidgetSpan](#widgetspan)

## Limitation

- Not support: it won't handle special text when TextDirection.rtl.

  Image position calculated by TextPainter is strange.

- Not support:it won't handle special text when obscureText is true.

## Speical Text

![](https://github.com/fluttercandies/Flutter_Candies/blob/master/gif/extended_text_field/extended_text_field.gif)

### Create Speical Text

extended text helps to convert your text to speical textSpan quickly.

for example, follwing code show how to create @xxxx speical textSpan.

```dart
class AtText extends SpecialText {
  static const String flag = "@";
  final int start;

  /// whether show background for @somebody
  final bool showAtBackground;

  AtText(TextStyle textStyle, SpecialTextGestureTapCallback onTap,
      {this.showAtBackground: false, this.start})
      : super(
          flag,
          " ",
          textStyle,
        );

  @override
  InlineSpan finishText() {
    TextStyle textStyle =
        this.textStyle?.copyWith(color: Colors.blue, fontSize: 16.0);

    final String atText = toString();

    return showAtBackground
        ? BackgroundTextSpan(
            background: Paint()..color = Colors.blue.withOpacity(0.15),
            text: atText,
            actualText: atText,
            start: start,

            ///caret can move into special text
            deleteAll: true,
            style: textStyle,
            recognizer: (TapGestureRecognizer()
              ..onTap = () {
                if (onTap != null) onTap(atText);
              }))
        : SpecialTextSpan(
            text: atText,
            actualText: atText,
            start: start,
            style: textStyle,
            recognizer: (TapGestureRecognizer()
              ..onTap = () {
                if (onTap != null) onTap(atText);
              }));
  }
}

```

### SpecialTextSpanBuilder

create your SpecialTextSpanBuilder

```dart
class MySpecialTextSpanBuilder extends SpecialTextSpanBuilder {
  /// whether show background for @somebody
  final bool showAtBackground;
  final BuilderType type;
  MySpecialTextSpanBuilder(
      {this.showAtBackground: false, this.type: BuilderType.extendedText});

  @override
  TextSpan build(String data, {TextStyle textStyle, onTap}) {
    var textSpan = super.build(data, textStyle: textStyle, onTap: onTap);
    return textSpan;
  }

  @override
  SpecialText createSpecialText(String flag,
      {TextStyle textStyle, SpecialTextGestureTapCallback onTap, int index}) {
    if (flag == null || flag == "") return null;

    ///index is end index of start flag, so text start index should be index-(flag.length-1)
    if (isStart(flag, AtText.flag)) {
      return AtText(textStyle, onTap,
          start: index - (AtText.flag.length - 1),
          showAtBackground: showAtBackground,
          type: type);
    } else if (isStart(flag, EmojiText.flag)) {
      return EmojiText(textStyle, start: index - (EmojiText.flag.length - 1));
    } else if (isStart(flag, DollarText.flag)) {
      return DollarText(textStyle, onTap,
          start: index - (DollarText.flag.length - 1), type: type);
    }
    return null;
  }
}
```

[more detail](https://github.com/fluttercandies/extended_text_field/blob/master/example/lib/pages/text_demo.dart)

## Image

![](https://github.com/fluttercandies/Flutter_Candies/blob/master/gif/extended_text_field/extended_text_field_image.gif)

### ImageSpan

show inline image by using ImageSpan.

```dart
ImageSpan(
    ImageProvider image, {
    Key key,
    @required double imageWidth,
    @required double imageHeight,
    EdgeInsets margin,
    int start: 0,
    ui.PlaceholderAlignment alignment = ui.PlaceholderAlignment.bottom,
    String actualText,
    TextBaseline baseline,
    TextStyle style,
    BoxFit fit: BoxFit.scaleDown,
    ImageLoadingBuilder loadingBuilder,
    ImageFrameBuilder frameBuilder,
    String semanticLabel,
    bool excludeFromSemantics = false,
    Color color,
    BlendMode colorBlendMode,
    AlignmentGeometry imageAlignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = false,
    FilterQuality filterQuality = FilterQuality.low,
  })

ImageSpan(AssetImage("xxx.jpg"),
        imageWidth: size,
        imageHeight: size,
        margin: EdgeInsets.only(left: 2.0, bottom: 0.0, right: 2.0));
  }
```

| parameter   | description                                                                   | default  |
| ----------- | ----------------------------------------------------------------------------- | -------- |
| image       | The image to display(ImageProvider).                                          | -        |
| imageWidth  | The width of image(not include margin)                                        | required |
| imageHeight | The height of image(not include margin)                                       | required |
| margin      | The margin of image                                                           | -        |
| actualText  | Actual text, take care of it when enable selection,something likes "\[love\]" | '\uFFFC' |
| start       | Start index of text,take care of it when enable selection.                    | 0        |

### Cache Image

if you want cache the network image, you can use ExtendedNetworkImageProvider and clear them with clearDiskCachedImages

import extended_image_library

```dart
dependencies:
  extended_image_library: ^0.1.4
```

```dart
ExtendedNetworkImageProvider(
  this.url, {
  this.scale = 1.0,
  this.headers,
  this.cache: false,
  this.retries = 3,
  this.timeLimit,
  this.timeRetry = const Duration(milliseconds: 100),
  CancellationToken cancelToken,
})  : assert(url != null),
      assert(scale != null),
      cancelToken = cancelToken ?? CancellationToken();
```

| parameter   | description                                                                           | default             |
| ----------- | ------------------------------------------------------------------------------------- | ------------------- |
| url         | The URL from which the image will be fetched.                                         | required            |
| scale       | The scale to place in the [ImageInfo] object of the image.                            | 1.0                 |
| headers     | The HTTP headers that will be used with [HttpClient.get] to fetch image from network. | -                   |
| cache       | whether cache image to local                                                          | false               |
| retries     | the time to retry to request                                                          | 3                   |
| timeLimit   | time limit to request image                                                           | -                   |
| timeRetry   | the time duration to retry to request                                                 | milliseconds: 100   |
| cancelToken | token to cancel network request                                                       | CancellationToken() |

```dart
/// Clear the disk cache directory then return if it succeed.
///  <param name="duration">timespan to compute whether file has expired or not</param>
Future<bool> clearDiskCachedImages({Duration duration}) async
```

[more detail](https://github.com/fluttercandies/extended_text_field/blob/master/example/lib/pages/text_demo.dart)

## TextSelectionControls

![](https://github.com/fluttercandies/Flutter_Candies/blob/master/gif/extended_text_field/custom_toolbar.gif)

default value of textSelectionControls are MaterialExtendedTextSelectionControls/CupertinoExtendedTextSelectionControls

override buildToolbar or buildHandle to custom your toolbar widget or handle widget

```dart
class MyExtendedMaterialTextSelectionControls
    extends MaterialExtendedTextSelectionControls {
  MyExtendedMaterialTextSelectionControls();
  @override
  Widget buildToolbar(
    BuildContext context,
    Rect globalEditableRegion,
    double textLineHeight,
    Offset position,
    List<TextSelectionPoint> endpoints,
    TextSelectionDelegate delegate,
  ) {
    assert(debugCheckHasMediaQuery(context));
    assert(debugCheckHasMaterialLocalizations(context));

    // The toolbar should appear below the TextField
    // when there is not enough space above the TextField to show it.
    final TextSelectionPoint startTextSelectionPoint = endpoints[0];
    final TextSelectionPoint endTextSelectionPoint =
        (endpoints.length > 1) ? endpoints[1] : null;
    final double x = (endTextSelectionPoint == null)
        ? startTextSelectionPoint.point.dx
        : (startTextSelectionPoint.point.dx + endTextSelectionPoint.point.dx) /
            2.0;
    final double availableHeight = globalEditableRegion.top -
        MediaQuery.of(context).padding.top -
        _kToolbarScreenPadding;
    final double y = (availableHeight < _kToolbarHeight)
        ? startTextSelectionPoint.point.dy +
            globalEditableRegion.height +
            _kToolbarHeight +
            _kToolbarScreenPadding
        : startTextSelectionPoint.point.dy - textLineHeight * 2.0;
    final Offset preciseMidpoint = Offset(x, y);

    return ConstrainedBox(
      constraints: BoxConstraints.tight(globalEditableRegion.size),
      child: CustomSingleChildLayout(
        delegate: MaterialExtendedTextSelectionToolbarLayout(
          MediaQuery.of(context).size,
          globalEditableRegion,
          preciseMidpoint,
        ),
        child: _TextSelectionToolbar(
          handleCut: canCut(delegate) ? () => handleCut(delegate) : null,
          handleCopy: canCopy(delegate) ? () => handleCopy(delegate) : null,
          handlePaste: canPaste(delegate) ? () => handlePaste(delegate) : null,
          handleSelectAll:
              canSelectAll(delegate) ? () => handleSelectAll(delegate) : null,
          handleLike: () {
            //mailto:<email address>?subject=<subject>&body=<body>, e.g.
            launch(
                "mailto:zmtzawqlp@live.com?subject=extended_text_share&body=${delegate.textEditingValue.text}");
            delegate.hideToolbar();
            //clear selecction
            delegate.textEditingValue = delegate.textEditingValue.copyWith(
                selection: TextSelection.collapsed(
                    offset: delegate.textEditingValue.selection.end));
          },
        ),
      ),
    );
  }

  @override
  Widget buildHandle(
      BuildContext context, TextSelectionHandleType type, double textHeight) {
    final Widget handle = SizedBox(
      width: _kHandleSize,
      height: _kHandleSize,
      child: Image.asset("assets/love.png"),
    );

    // [handle] is a circle, with a rectangle in the top left quadrant of that
    // circle (an onion pointing to 10:30). We rotate [handle] to point
    // straight up or up-right depending on the handle type.
    switch (type) {
      case TextSelectionHandleType.left: // points up-right
        return Transform.rotate(
          angle: math.pi / 4.0,
          child: handle,
        );
      case TextSelectionHandleType.right: // points up-left
        return Transform.rotate(
          angle: -math.pi / 4.0,
          child: handle,
        );
      case TextSelectionHandleType.collapsed: // points up
        return handle;
    }
    assert(type != null);
    return null;
  }
}

/// Manages a copy/paste text selection toolbar.
class _TextSelectionToolbar extends StatelessWidget {
  const _TextSelectionToolbar({
    Key key,
    this.handleCopy,
    this.handleSelectAll,
    this.handleCut,
    this.handlePaste,
    this.handleLike,
  }) : super(key: key);

  final VoidCallback handleCut;
  final VoidCallback handleCopy;
  final VoidCallback handlePaste;
  final VoidCallback handleSelectAll;
  final VoidCallback handleLike;

  @override
  Widget build(BuildContext context) {
    final List<Widget> items = <Widget>[];
    final MaterialLocalizations localizations =
        MaterialLocalizations.of(context);

    if (handleCut != null)
      items.add(FlatButton(
          child: Text(localizations.cutButtonLabel), onPressed: handleCut));
    if (handleCopy != null)
      items.add(FlatButton(
          child: Text(localizations.copyButtonLabel), onPressed: handleCopy));
    if (handlePaste != null)
      items.add(FlatButton(
        child: Text(localizations.pasteButtonLabel),
        onPressed: handlePaste,
      ));
    if (handleSelectAll != null)
      items.add(FlatButton(
          child: Text(localizations.selectAllButtonLabel),
          onPressed: handleSelectAll));

    if (handleLike != null)
      items.add(FlatButton(child: Icon(Icons.favorite), onPressed: handleLike));

    // If there is no option available, build an empty widget.
    if (items.isEmpty) {
      return Container(width: 0.0, height: 0.0);
    }

    return Material(
      elevation: 1.0,
      child: Wrap(children: items),
      borderRadius: BorderRadius.all(Radius.circular(10.0)),
    );
  }
}

```

[more detail](https://github.com/fluttercandies/extended_text_field/blob/master/example/lib/pages/custom_toolbar.dart)

## WidgetSpan

![](https://github.com/fluttercandies/Flutter_Candies/blob/master/gif/extended_text_field/widget_span.gif)

support to select and hitTest ExtendedWidgetSpan, you can create any widget in ExtendedTextField.

```dart
class EmailText extends SpecialText {
  final TextEditingController controller;
  final int start;
  final BuildContext context;
  EmailText(TextStyle textStyle, SpecialTextGestureTapCallback onTap,
      {this.start, this.controller, this.context, String startFlag})
      : super(startFlag, " ", textStyle, onTap: onTap);

  @override
  bool isEnd(String value) {
    var index = value.indexOf("@");
    var index1 = value.indexOf(".");

    return index >= 0 &&
        index1 >= 0 &&
        index1 > index + 1 &&
        super.isEnd(value);
  }

  @override
  InlineSpan finishText() {
    final String text = toString();

    return ExtendedWidgetSpan(
      actualText: text,
      start: start,
      alignment: ui.PlaceholderAlignment.middle,
      child: GestureDetector(
        child: Padding(
          padding: EdgeInsets.only(right: 5.0, top: 2.0, bottom: 2.0),
          child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(5.0)),
              child: Container(
                padding: EdgeInsets.all(5.0),
                color: Colors.orange,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      text.trim(),
                      //style: textStyle?.copyWith(color: Colors.orange),
                    ),
                    SizedBox(
                      width: 5.0,
                    ),
                    InkWell(
                      child: Icon(
                        Icons.close,
                        size: 15.0,
                      ),
                      onTap: () {
                        controller.value = controller.value.copyWith(
                            text: controller.text
                                .replaceRange(start, start + text.length, ""),
                            selection: TextSelection.fromPosition(
                                TextPosition(offset: start)));
                      },
                    )
                  ],
                ),
              )),
        ),
        onTap: () {
          showDialog(
              context: context,
              barrierDismissible: true,
              builder: (c) {
                TextEditingController textEditingController =
                    TextEditingController()..text = text.trim();
                return Column(
                  children: <Widget>[
                    Expanded(
                      child: Container(),
                    ),
                    Material(
                        child: Padding(
                      padding: EdgeInsets.all(10.0),
                      child: TextField(
                        controller: textEditingController,
                        decoration: InputDecoration(
                            suffixIcon: FlatButton(
                          child: Text("OK"),
                          onPressed: () {
                            controller.value = controller.value.copyWith(
                                text: controller.text.replaceRange(
                                    start,
                                    start + text.length,
                                    textEditingController.text + " "),
                                selection: TextSelection.fromPosition(
                                    TextPosition(
                                        offset: start +
                                            (textEditingController.text + " ")
                                                .length)));

                            Navigator.pop(context);
                          },
                        )),
                      ),
                    )),
                    Expanded(
                      child: Container(),
                    )
                  ],
                );
              });
        },
      ),
      deleteAll: true,
    );
  }
}
```

[more detail](https://github.com/fluttercandies/extended_text_field/blob/master/example/lib/pages/widget_span.dart)

## ☕️Buy me a coffee

![img](http://zmtzawqlp.gitee.io/my_images/images/qrcode.png)
