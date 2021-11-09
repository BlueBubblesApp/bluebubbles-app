import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SetupMacApp extends StatelessWidget {
  const SetupMacApp({Key? key, required this.controller}) : super(key: key);
  final PageController controller;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent, // navigation bar color
        systemNavigationBarIconBrightness: Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).accentColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  "Before using the Android App, please verify that you have already installed the macOS Server app. Additionally, make sure that your iMessage app is signed into an iCloud/Apple account.",
                  style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeFactor: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
              Container(height: 20.0),
              ClipOval(
                child: Material(
                  color: Theme.of(context).primaryColor, // button color
                  child: InkWell(
                    child: SizedBox(width: 60, height: 60, child: Icon(Icons.check, color: Colors.white)),
                    onTap: () async {
                      controller.nextPage(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ),
              ),
              Container(height: 20.0),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  "If you have not installed the macOS Server app, please go to the following link on your macOS device to download it:\n\nhttps://bluebubbles.app",
                  style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeFactor: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
