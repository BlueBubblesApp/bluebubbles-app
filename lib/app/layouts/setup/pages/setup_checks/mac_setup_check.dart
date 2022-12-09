import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/app/layouts/setup/pages/page_template.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

class MacSetupCheck extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SetupPageTemplate(
      title: "Setup Check",
      subtitle: "Please ensure you have set up the BlueBubbles Server on macOS before proceeding.\n\nAdditionally, please ensure iMessage is signed into your Apple ID on macOS.",
      belowSubtitle: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 13),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                colors: [HexColor('2772C3'), HexColor('5CA7F8').darkenPercent(5)],
              ),
            ),
            height: 40,
            child: ElevatedButton(
              style: ButtonStyle(
                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                ),
                backgroundColor: MaterialStateProperty.all(Colors.transparent),
                shadowColor: MaterialStateProperty.all(Colors.transparent),
                maximumSize: MaterialStateProperty.all(const Size(300, 36)),
                minimumSize: MaterialStateProperty.all(const Size(30, 30)),
              ),
              onPressed: () async {
                await launchUrl(Uri(scheme: "https", host: "bluebubbles.app", path: "install"), mode: LaunchMode.externalApplication);
              },
              child: Shimmer.fromColors(
                baseColor: Colors.white70,
                highlightColor: Colors.white,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Server setup instructions",
                      style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: Colors.white)
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
