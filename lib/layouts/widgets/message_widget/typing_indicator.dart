import 'package:flutter/material.dart';

class TypingIndicator extends StatefulWidget {
  TypingIndicator({Key key}) : super(key: key);

  @override
  _TypingIndicatorState createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          width: MediaQuery.of(context).size.width * 1 / 4,
          height: MediaQuery.of(context).size.width * 1 / 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: Theme.of(context).accentColor,
          ),
        ),
      ],
    );
  }
}
