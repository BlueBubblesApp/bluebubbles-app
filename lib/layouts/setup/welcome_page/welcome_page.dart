import 'package:bluebubbles/helpers/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class WelcomePage extends StatefulWidget {
  WelcomePage({Key? key, this.controller}) : super(key: key);
  final PageController? controller;

  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with TickerProviderStateMixin {
  late AnimationController _titleController;
  late AnimationController _subtitleController;

  // Animation<double> opacityTitle;
  late Animation<double> opacityTitle;
  late Animation<Offset> titleOffset;
  late Animation<double> opacitySubtitle;
  late Animation<Offset> subtitleOffset;
  late Animation<double> opacityButton;

  @override
  void initState() {
    super.initState();
    _titleController = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this);

    SchedulerBinding.instance!.addPostFrameCallback((_) async {
      await animateTitle();
      await animateSubtitle();
    });
    _titleController = AnimationController(vsync: this, duration: Duration(seconds: 1));
    titleOffset = Tween<Offset>(begin: Offset(0.0, 3), end: Offset(0.0, 0.0))
        .animate(CurvedAnimation(parent: _titleController, curve: Curves.easeInOut));

    opacityTitle =
        Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _titleController, curve: Curves.easeInOut));

    _subtitleController = AnimationController(vsync: this, duration: Duration(seconds: 1));
    subtitleOffset = Tween<Offset>(begin: Offset(0.0, 5), end: Offset(0.0, 2))
        .animate(CurvedAnimation(parent: _subtitleController, curve: Curves.easeInOut));

    opacitySubtitle = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _subtitleController, curve: Curves.easeInOut));

    opacityButton = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _subtitleController, curve: Curves.easeInOut));
  }

  Future<void> animateTitle() async {
    _titleController.forward();
    await Future.delayed(Duration(milliseconds: 500));
  }

  Future<void> animateSubtitle() async {
    _subtitleController.forward();
    await Future.delayed(Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

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
        body: Padding(
          padding: const EdgeInsets.symmetric(vertical: 80.0, horizontal: 24.0),
          child: Stack(
            children: <Widget>[
              SlideTransition(
                position: titleOffset,
                child: FadeTransition(
                  opacity: opacityTitle,
                  child: Text(
                    "Welcome to BlueBubbles",
                    style: Theme.of(context).textTheme.headline1!.apply(
                          fontSizeDelta: 7,
                        ),
                  ),
                ),
              ),
              SlideTransition(
                position: subtitleOffset,
                child: FadeTransition(
                  opacity: opacitySubtitle,
                  child: Text(
                    "Let's get started",
                    style: Theme.of(context).textTheme.headline1,
                  ),
                ),
              ),
              Center(
                child: FadeTransition(
                  opacity: opacityButton,
                  child: ClipOval(
                    child: Material(
                      color: Theme.of(context).primaryColor, // button color
                      child: InkWell(
                          child: SizedBox(width: 60, height: 60, child: Icon(Icons.arrow_forward, color: Colors.white)),
                          onTap: () async {
                            if (!kIsWeb && !kIsDesktop && await Permission.contacts.isGranted) {
                              widget.controller!.animateToPage(
                                2,
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              widget.controller!.nextPage(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          }),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
