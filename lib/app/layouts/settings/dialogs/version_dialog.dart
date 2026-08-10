import 'dart:math';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

void showVersionDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
            return AlertDialog(
              contentPadding: const EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
              ),
              elevation: 10.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  10.0,
                ),
              ),
              scrollable: true,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              content: ListBody(
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      IconTheme(
                        data: Theme.of(context).iconTheme,
                        child: Image.asset(
                          "assets/icon/icon.png",
                          width: 30,
                          height: 30,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: ListBody(
                            children: <Widget>[
                              Text(
                                "BlueBubbles",
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              if (!kIsDesktop)
                                Text(
                                    "Version Number: ${snapshot.hasData ? snapshot.data!.version : "N/A"}",
                                    style: Theme.of(context).textTheme.bodyLarge),
                              if (!kIsDesktop)
                                Text(
                                    "Version Code: ${snapshot.hasData ? snapshot.data!.buildNumber.toString().lastChars(min(4, snapshot.data!.buildNumber.length)) : "N/A"}",
                                    style: Theme.of(context).textTheme.bodyLarge),
                              if (kIsDesktop)
                                Text(
                                  appVersion,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: Text("View Licenses",
                      style: Theme.of(context).textTheme.bodyLarge!
                          .copyWith(color: Theme.of(context).colorScheme.primary)),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (BuildContext context) => Theme(
                        data: Theme.of(context),
                        child: LicensePage(
                          applicationName: "BlueBubbles",
                          applicationVersion: snapshot.hasData ? snapshot.data!.version : "",
                          applicationIcon: Image.asset(
                            "assets/icon/icon.png",
                            width: 30,
                            height: 30,
                          ),
                        ),
                      ),
                    ));
                  },
                ),
                TextButton(
                  child: Text("Close",
                      style: Theme.of(context).textTheme.bodyLarge!
                          .copyWith(color: Theme.of(context).colorScheme.primary)),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            );
          });
    },
  );
}
