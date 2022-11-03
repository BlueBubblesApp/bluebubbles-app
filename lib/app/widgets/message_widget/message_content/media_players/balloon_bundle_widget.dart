import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/helpers/types/helpers/message_helper.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BalloonBundleWidget extends StatefulWidget {
  BalloonBundleWidget({
    Key? key,
    required this.message,
  }) : super(key: key);
  final Message? message;

  @override
  State<BalloonBundleWidget> createState() => _BalloonBubbleState();
}

class _BalloonBubbleState extends State<BalloonBundleWidget> {
  late String bundleName;
  late IconData bundleIcon;

  @override
  void initState() {
    super.initState();

    bundleName = widget.message!.interactiveText;
    bundleIcon = getIcon();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() {
      bundleName = widget.message!.interactiveText;
      bundleIcon = getIcon();
    });
  }

  IconData getIcon() {
    final balloonBundleId = widget.message!.balloonBundleId;
    final temp = balloonBundleIdIconMap[balloonBundleId?.split(":").first];
    IconData? icon;
    if (temp is Map) {
      icon = temp[balloonBundleId?.split(":").last];
    } else if (temp is IconData) {
      icon = temp;
    }

    return icon ?? (ss.settings.skin.value == Skins.iOS ? CupertinoIcons.square_grid_3x2 : Icons.apps);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 13.0, right: widget.message!.isFromMe! ? 0 : 13, left: widget.message!.isFromMe! ? 13 : 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
            constraints: BoxConstraints(
              maxWidth: ns.width(context) * 3 / 4,
            ),
            child: Container(
              width: 200,
              color: context.theme.colorScheme.properSurface,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(bundleName,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.textTheme.titleLarge),
                    Text("Interactive Message",
                        textAlign: TextAlign.center, maxLines: 1, style: context.theme.textTheme.bodyMedium),
                    Container(height: 10.0),
                    Icon(bundleIcon, color: context.theme.colorScheme.properOnSurface, size: 48),
                    Container(height: 10.0),
                    Text("(Cannot open on Android)",
                        textAlign: TextAlign.center, maxLines: 1, style: context.theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            )),
      ),
    );
  }
}
