import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get_utils/src/extensions/context_extensions.dart';

class SearchTextBox extends StatelessWidget {
  SearchTextBox({Key? key, this.autoFocus = false}) : super(key: key);
  final bool autoFocus;

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      cursorColor: context.theme.primaryColor,
      autofocus: autoFocus,
      decoration: BoxDecoration(
        color: context.theme.colorScheme.secondary,
        borderRadius: BorderRadius.circular(10),
      ),
      placeholder: "Search",
      placeholderStyle: Theme.of(context).textTheme.bodyText1!.apply(
            color: Theme.of(context).textTheme.bodyText1!.color!.lightenOrDarken(40),
          ),
      style: Theme.of(context).textTheme.bodyText1,
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
    );
  }
}
