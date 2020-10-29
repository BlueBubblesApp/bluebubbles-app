import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class NewMessageLoader extends StatefulWidget {
  final MessageBloc messageBloc;
  final int offset;
  final Future loader;
  NewMessageLoader({
    Key key,
    this.messageBloc,
    this.offset,
    this.loader,
  }) : super(key: key);

  @override
  _NewMessageLoaderState createState() => _NewMessageLoaderState();
}

class _NewMessageLoaderState extends State<NewMessageLoader> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loader == null) return Container();

    return FutureBuilder(
      future: widget.loader,
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Container();
        }
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Loading more messages...",
                style: Theme.of(context).textTheme.subtitle2,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Theme(
                data: ThemeData(
                  cupertinoOverrideTheme: CupertinoThemeData(
                      brightness: Brightness.dark
                  )
                ), 
                child: CupertinoActivityIndicator()
              )
            ),
          ],
        );
      },
    );
  }
}
