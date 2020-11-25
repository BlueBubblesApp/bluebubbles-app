import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:permission_handler/permission_handler.dart';

class WelcomePage extends StatefulWidget {
  WelcomePage({Key key, this.controller}) : super(key: key);
  final PageController controller;

  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with TickerProviderStateMixin {
  AnimationController _titleController;
  AnimationController _subtitleController;
  // Animation<double> opacityTitle;
  Animation<double> opacityTitle;
  Animation<Offset> titleOffset;
  Animation<double> opacitySubtitle;
  Animation<Offset> subtitleOffset;
  Animation<double> opacityButton;

  @override
  void initState() {
    super.initState();
    _titleController = AnimationController(
        duration: const Duration(milliseconds: 2000), vsync: this);

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await animateTitle();
      await animateSubtitle();
    });
    _titleController =
        AnimationController(vsync: this, duration: Duration(seconds: 1));
    titleOffset = Tween<Offset>(begin: Offset(0.0, 3), end: Offset(0.0, 0.0))
        .animate(new CurvedAnimation(
            parent: _titleController, curve: Curves.easeInOut));

    opacityTitle = Tween<double>(begin: 0, end: 1).animate(
        new CurvedAnimation(parent: _titleController, curve: Curves.easeInOut));

    _subtitleController =
        AnimationController(vsync: this, duration: Duration(seconds: 1));
    subtitleOffset = Tween<Offset>(begin: Offset(0.0, 5), end: Offset(0.0, 2))
        .animate(new CurvedAnimation(
            parent: _subtitleController, curve: Curves.easeInOut));

    opacitySubtitle = Tween<double>(begin: 0, end: 1).animate(
        new CurvedAnimation(
            parent: _subtitleController, curve: Curves.easeInOut));

    opacityButton = Tween<double>(begin: 0, end: 1).animate(new CurvedAnimation(
        parent: _subtitleController, curve: Curves.easeInOut));
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  style: Theme.of(context).textTheme.headline1.apply(
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
                        child: SizedBox(
                            width: 60,
                            height: 60,
                            child:
                                Icon(Icons.arrow_forward, color: Colors.white)),
                        onTap: () async {
                          if (await Permission.contacts.isGranted) {
                            widget.controller.animateToPage(
                              2,
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            widget.controller.nextPage(
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
    );
  }
}
