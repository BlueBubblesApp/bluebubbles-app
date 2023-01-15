import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';

class InitialWidgetRight extends StatefulWidget {
  const InitialWidgetRight({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _InitialWidgetRightState();
}

class _InitialWidgetRightState extends OptimizedState<InitialWidgetRight> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Center(
        child: Container(
          child: Text(
            "Select a chat from the list",
            style: context.theme.textTheme.bodyLarge
          )
        ),
      ),
    );
  }
}
