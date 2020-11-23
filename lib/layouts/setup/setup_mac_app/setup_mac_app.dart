import 'package:flutter/material.dart';

class SetupMacApp extends StatelessWidget {
  const SetupMacApp({Key key, @required this.controller}) : super(key: key);
  final PageController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).accentColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                "Next download the BlueBubbles Server app on your Mac and install. Follow the setup process",
                style: Theme.of(context)
                    .textTheme
                    .bodyText1
                    .apply(fontSizeFactor: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
            Container(height: 20.0),
            ClipOval(
              child: Material(
                color: Theme.of(context).primaryColor, // button color
                child: InkWell(
                  child: SizedBox(
                      width: 60,
                      height: 60,
                      child: Icon(Icons.check, color: Colors.white)),
                  onTap: () async {
                    controller.nextPage(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
