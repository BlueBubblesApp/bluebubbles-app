import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UpgradingDB extends StatelessWidget {
  const UpgradingDB({Key? key, this.e, this.otherTitle}) : super(key: key);
  final dynamic e;
  final String? otherTitle;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlueBubbles',
      home: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          systemNavigationBarColor: Theme.of(context).backgroundColor, // navigation bar color
          systemNavigationBarIconBrightness:
              Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
          statusBarColor: Colors.transparent, // status bar color
        ),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                Center(
                  child: Text(
                    "Upgrading Database...",
                    style: TextStyle(color: Colors.white, fontSize: 30),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: Center(
                    child: Text("Please wait, this shouldn't take longer than 15 seconds...",
                        style: TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
