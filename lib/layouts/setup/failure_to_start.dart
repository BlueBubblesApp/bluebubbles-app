import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FailureToStrt extends StatelessWidget {
  const FailureToStrt({Key key, this.e}) : super(key: key);
  final dynamic e;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlueBubbles',
      home: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.black,
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
                    "Whoops, looks like we messed up. Unfortunately you will need to reinstall the app, sorry for the inconvenience :(",
                    style: TextStyle(color: Colors.white, fontSize: 30),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: Center(
                    child: Text("Error: ${e.toString()}",
                        style: TextStyle(color: Colors.white, fontSize: 10)),
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
