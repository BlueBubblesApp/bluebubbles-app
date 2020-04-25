import './hex_color.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'conversation_view.dart';

class ConversationTile extends StatefulWidget {
  final data;
  final Function requestMessages;

  ConversationTile({Key key, this.data, this.requestMessages})
      : super(key: key);

  @override
  _ConversationTileState createState() => _ConversationTileState();
}

class _ConversationTileState extends State<ConversationTile> {
  String title = "";

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    if (widget.data == null || widget.data["displayName"] == "") {
      // title = widget.data["participants"]
      // .map((participant) => participant["id"] + ", ");
      String _title = "";
      for (int i = 0; i < widget.data["participants"].length; i++) {
        var participant = widget.data["participants"][i];
        _title += (participant["id"] + ", ").toString();
      }
      debugPrint(_title.toString());
      title = _title;
    } else {
      title = widget.data["displayName"];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: InkWell(
        onTap: () {
          if (widget.data["chatIdentifier"] != null) {
            widget.requestMessages({
              "identifier": widget.data["chatIdentifier"],
              "limit": 100,
            }, (data) {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (BuildContext context) {
                    return ConversationView(
                      messages: data,
                    );
                  },
                ),
              );
            });
          } else {
            debugPrint("widget chatIdentifier is null");
          }
        },
        child: ListTile(
          title: Text(
            title,
            style: TextStyle(
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            "most recent message",
            style: TextStyle(
              color: HexColor('36363a'),
            ),
            maxLines: 1,
          ),
          leading: CircleAvatar(
            radius: 20,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  colors: [HexColor('a0a4af'), HexColor('848894')],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Container(
                child: Text("BW"),
                alignment: AlignmentDirectional.center,
              ),
            ),
          ),
          trailing: Container(
            width: 70,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  padding: EdgeInsets.only(right: 10),
                  child: Text(
                    "4:20",
                    style: TextStyle(
                      color: HexColor('36363a'),
                      fontSize: 10,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: HexColor('36363a'),
                  size: 15,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
