import 'dart:convert';
import 'dart:ui';

// import 'package:bluebubble_messages/qr_code_scanner.dart';
import 'package:bluebubble_messages/settings.dart';
import 'package:bluebubble_messages/singleton.dart';
import 'package:flutter/cupertino.dart';

import './hex_color.dart';
import 'package:flutter/material.dart';

import 'qr_code_scanner.dart';

class SettingsPanel extends StatefulWidget {
  // final Settings settings;
  // final Function saveSettings;

  SettingsPanel({Key key}) : super(key: key);

  @override
  _SettingsPanelState createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  Settings _settingsCopy;

  @override
  void initState() {
    super.initState();
    _settingsCopy = Singleton().settings;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: Size(MediaQuery.of(context).size.width, 80),
        child: ClipRRect(
          child: BackdropFilter(
            child: AppBar(
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              backgroundColor: HexColor('26262a').withOpacity(0.5),
            ),
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          ),
        ),
      ),
      body: ListView(
        physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: <Widget>[
          SettingsTile(
            title: "Scan QR Code From Mac Server",
            trailing: Icon(Icons.camera, color: HexColor('26262a')),
            onTap: () async {
              var fcmData;
              try {
                fcmData = jsonDecode(
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (BuildContext context) {
                        return QRCodeScanner();
                      },
                    ),
                  ),
                );
              } catch (e) {
                return;
              }
              if (fcmData != null) {
                _settingsCopy.fcmAuthData = {
                  "project_id": fcmData[2],
                  "storage_bucket": fcmData[3],
                  "api_key": fcmData[4],
                  "firebase_url": fcmData[5],
                  "client_id": fcmData[6],
                  "application_id": fcmData[7],
                };
                _settingsCopy.guidAuthKey = fcmData[0];
                _settingsCopy.serverAddress = fcmData[1];
                // Singleton().saveSettings(_settingsCopy);
              }
            },
          ),
          SettingsTile(
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  TextEditingController _controller = TextEditingController(
                    text: "https://.ngrok.io",
                  );
                  _controller.selection =
                      TextSelection.fromPosition(TextPosition(offset: 8));

                  return AlertDialog(
                    title: Text(
                      "Server address:",
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                    content: Container(
                      child: TextField(
                        autofocus: true,
                        controller: _controller,
                        // autofocus: true,
                        scrollPhysics: BouncingScrollPhysics(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.only(top: 5, bottom: 5),
                          // border: InputBorder.none,
                          // border: OutlineInputBorder(),
                          // hintText: 'https://<some-id>.ngrok.com',
                          hintStyle: TextStyle(
                            color: Color.fromARGB(255, 100, 100, 100),
                          ),
                        ),
                      ),
                    ),
                    backgroundColor: HexColor('26262a'),
                    actions: <Widget>[
                      FlatButton(
                        child: Text("Ok"),
                        onPressed: () {
                          _settingsCopy.serverAddress = _controller.text;
                          // Singleton().saveSettings(_settingsCopy);
                          Navigator.of(context).pop();
                        },
                      ),
                      FlatButton(
                        child: Text("Cancel"),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );
                },
              );
            },
            title: "Current address",
            subTitle: _settingsCopy.serverAddress,
            trailing: Icon(Icons.edit, color: HexColor('26262a')),
          ),
          SettingsSlider(
            startingVal: _settingsCopy.chunkSize.toDouble(),
            update: (int val) {
              _settingsCopy.chunkSize = val;
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // TODO: implement dispose
    // if (_settingsCopy != Singleton().settings) {
    debugPrint("saving settings");
    Singleton().saveSettings(_settingsCopy);
    // }
    super.dispose();
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile(
      {Key key, this.onTap, this.title, this.trailing, this.subTitle})
      : super(key: key);

  final Function onTap;
  final String subTitle;
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: InkWell(
        onTap: this.onTap,
        child: Column(
          children: <Widget>[
            ListTile(
              title: Text(
                this.title,
                style: TextStyle(color: Colors.white),
              ),
              trailing: this.trailing,
              subtitle: subTitle != null
                  ? Text(
                      subTitle,
                      style: TextStyle(
                        color: HexColor('26262a'),
                      ),
                    )
                  : null,
            ),
            Divider(
              color: HexColor('26262a').withOpacity(0.5),
              thickness: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsSlider extends StatefulWidget {
  SettingsSlider({this.startingVal, this.update, Key key}) : super(key: key);

  final double startingVal;
  final Function update;

  @override
  _SettingsSliderState createState() => _SettingsSliderState();
}

class _SettingsSliderState extends State<SettingsSlider> {
  double currentVal = 1;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    debugPrint(widget.startingVal.toString());
    if (widget.startingVal > 1 && widget.startingVal < 5000) {
      currentVal = widget.startingVal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        ListTile(
          title: Text(
            "Chunk Size",
            style: TextStyle(color: Colors.white),
          ),
          subtitle: Slider(
            value: currentVal,
            onChanged: (double value) {
              debugPrint(value.toString());
              setState(() {
                currentVal = value;
                widget.update(currentVal.floor());
              });
            },
            label: currentVal < 1000
                ? "${(currentVal * 1024 / 1000).floor()}kb"
                : "${(currentVal * 1024 * 0.000001).floor()}mb",
            divisions: 20,
            min: 1,
            max: 5000,
          ),
        ),
        Divider(
          color: HexColor('26262a').withOpacity(0.5),
          thickness: 1,
        ),
      ],
    );
  }
}
