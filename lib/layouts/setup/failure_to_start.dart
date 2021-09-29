import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FailureToStart extends StatelessWidget {
  const FailureToStart({Key? key, this.e, this.otherTitle}) : super(key: key);
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
                    otherTitle ??
                        "Whoops, looks like we messed up. Unfortunately you will need to reinstall the app, sorry for the inconvenience :(",
                    style: TextStyle(color: Colors.white, fontSize: 30),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: Center(
                    child: Text("Error: ${e.toString()}", style: TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
