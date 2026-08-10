import 'package:bluebubbles/app/layouts/setup/setup_view.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.shouldNavigate});

  final bool shouldNavigate;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool didNavigate = false;

  void navigate() async {
    if (widget.shouldNavigate && !didNavigate) {
      didNavigate = true;
      await Future.delayed(const Duration(milliseconds: 100));
      Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
              transitionDuration: const Duration(seconds: 1),
              pageBuilder: (_, _, _) => const TitleBarWrapper(child: SetupView())),
          (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: context.theme.colorScheme.surface,
        body: Center(
          child: Hero(
              tag: "setup-icon",
              child: Image.asset("assets/icon/icon.png", width: 150, fit: BoxFit.contain,
                  frameBuilder: (context, child, frame, _) {
                if (frame != null) {
                  navigate();
                }
                return child;
              })),
        ));
  }
}
