import 'dart:math';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/backend/settings/settings_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SlideToReply extends StatelessWidget {
  const SlideToReply({super.key, required this.width, required this.isFromMe});
  
  final double width;
  final bool isFromMe;
  static const double replyThreshold = 40;

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: Duration(milliseconds: width == 0 ? 150 : 0),
      padding: EdgeInsets.only(left: width == 0 || isFromMe ? 0 : 10, right: width == 0 || !isFromMe ? 0 : 10),
      child: AnimatedContainer(
        duration: Duration(milliseconds: width == 0 ? 150 : 0),
        width: min(replyThreshold, width) * 0.8,
        height: min(replyThreshold, width) * 0.8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(
            Radius.circular(
              min(replyThreshold, width) * 0.4,
            ),
          ),
          color: context.theme.colorScheme.properSurface,
        ),
        child: AnimatedSize(
          duration: Duration(milliseconds: width == 0 ? 150 : 0),
          child: Offstage(
            offstage: kIsWeb && width == 0,
            child: Icon(
              ss.settings.skin.value == Skins.iOS ? CupertinoIcons.reply : Icons.reply,
              size: min(replyThreshold, width) * (width >= replyThreshold ? 0.5 : 0.4),
              color: context.theme.colorScheme.properOnSurface,
            ),
          ),
        ),
      ),
    );
  }
}
