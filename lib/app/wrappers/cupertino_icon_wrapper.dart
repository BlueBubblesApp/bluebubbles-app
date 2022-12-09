import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';

class CupertinoIconWrapper extends StatelessWidget {
  const CupertinoIconWrapper({Key? key, required Icon this.icon}) : super(key: key);

  final Widget icon;

  @override
  Widget build(BuildContext context) {
    if (ss.settings.skin.value != Skins.iOS) return icon;
    return Padding(
      padding: const EdgeInsets.only(left: 1.0),
      child: icon
    );
  }
}