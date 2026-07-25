import 'dart:math';

import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';

/// Shared width for iOS collage and stack collection cards.
double collectionCardWidth(BuildContext context) =>
    min(NavigationSvc.width(context) * 0.42, 220.0);

/// Author-side inset matching single attachments / [TailClipper] (galleries skip the clipper).
const double collectionEdgeInset = 10.0;

EdgeInsets collectionAuthorEdgeInsets({required bool isFromMe}) => EdgeInsets.only(
      left: isFromMe ? 0 : collectionEdgeInset,
      right: isFromMe ? collectionEdgeInset : 0,
    );
