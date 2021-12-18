import 'package:bluebubbles/layouts/setup/setup_view.dart';
import 'package:bluebubbles/layouts/titlebar_wrapper.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  SplashScreen({Key? key, required this.shouldNavigate}) : super(key: key);

  final bool shouldNavigate;

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool didNavigate = false;

  @override
  void initState() {
    super.initState();
  }

  void navigate() async {
    if (widget.shouldNavigate && !didNavigate) {
      didNavigate = true;
      await Future.delayed(Duration(milliseconds: 100));
      Navigator.of(context).pushAndRemoveUntil(PageRouteBuilder(
          transitionDuration: Duration(seconds: 1),
          pageBuilder: (_, __, ___) => TitleBarWrapper(child: SetupView())), (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        body: Center(
          child: Hero(
            tag: "setup-icon",
            child: Image.asset("assets/icon/icon.png", width: 150, fit: BoxFit.contain, frameBuilder: (context, child, frame, _) {
              if (frame != null) {
                navigate();
              }
              return child;
            })
          ),
        )
    );
  }
}
