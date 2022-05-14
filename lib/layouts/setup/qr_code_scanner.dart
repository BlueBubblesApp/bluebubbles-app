import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRCodeScanner extends StatefulWidget {
  QRCodeScanner({Key? key}) : super(key: key);

  @override
  State<QRCodeScanner> createState() => _QRCodeScannerState();
}

class _QRCodeScannerState extends State<QRCodeScanner> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness: Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        body: MobileScanner(
          key: qrKey,
          allowDuplicates: false,
          onDetect: (barcode, args) {
            if (!isNullOrEmpty(barcode.rawValue)!) {
              Navigator.of(context).pop(barcode.rawValue);
            }
          },
        ),
      ),
    );
  }
}
