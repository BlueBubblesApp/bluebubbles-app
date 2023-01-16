import 'dart:convert';

import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';

class BackupRestoreDialog extends StatelessWidget {
  const BackupRestoreDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.theme.colorScheme.properSurface,
      title: Text("Backup and Restore", style: context.theme.textTheme.titleLarge),
      content: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              height: 15.0,
            ),
            Text("Load From / Save To Server", style: context.theme.textTheme.labelLarge),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Container(color: context.theme.textTheme.labelLarge!.color, height: 0.5),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: context.theme.colorScheme.onPrimary,
                    backgroundColor: context.theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    disabledForegroundColor: context.theme.colorScheme.properOnSurface.withOpacity(0.38),
                    disabledBackgroundColor: context.theme.colorScheme.properOnSurface.withOpacity(0.12),
                    textStyle: context.theme.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.onPrimary),
                  ),
                  onPressed: () async {
                    DateTime now = DateTime.now().toLocal();
                    String name = "Android_${now.year}-${now.month}-${now.day}_${now.hour}-${now.minute}-${now.second}";
                    Map<String, dynamic> json = ss.settings.toMap();
                    var response = await http.setSettings(name, json);
                    if (response.statusCode != 200) {
                      Get.back();
                      showSnackbar(
                        "Error",
                        "Somthing went wrong",
                      );
                    } else {
                      Get.back();
                      showSnackbar(
                        "Success",
                        "Settings exported successfully to server",
                      );
                    }
                  },
                  child: Text(
                    "Save Settings",
                    style: TextStyle(
                      color: context.theme.colorScheme.onPrimary,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: context.theme.colorScheme.onPrimary,
                    backgroundColor: context.theme.colorScheme.properSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: context.theme.colorScheme.primary)
                    ),
                    disabledForegroundColor: context.theme.colorScheme.properOnSurface.withOpacity(0.38),
                    disabledBackgroundColor: context.theme.colorScheme.properOnSurface.withOpacity(0.12),
                    textStyle: context.theme.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                  ),
                  onPressed: () async {
                    var response = await http.getSettings();
                    if (response.statusCode == 200 && response.data.isNotEmpty) {
                      try {
                        List<dynamic> json = response.data['data'];
                        Get.back();
                        showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text("Settings Backups", style: context.theme.textTheme.titleLarge),
                              backgroundColor: context.theme.colorScheme.properSurface,
                              content: Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 300,
                                ),
                                child: Container(
                                  width: 300,
                                  height: 300,
                                  constraints: BoxConstraints(
                                    maxHeight: Get.height - 300,
                                  ),
                                  child: StatefulBuilder(
                                      builder: (context, setState) {
                                        return SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Text("Select the backup you would like to restore", style: context.theme.textTheme.bodyLarge),
                                              ),
                                              ListView.builder(
                                                shrinkWrap: true,
                                                itemCount: json.length,
                                                physics: const NeverScrollableScrollPhysics(),
                                                itemBuilder: (context, index) {
                                                  String finalName = "";
                                                  if(json[index]['name'].toString().contains("-")){
                                                    String date = json[index]['name'].toString().split("_")[1];
                                                    String time = json[index]['name'].toString().split("_")[2];
                                                    String year = date.split("-")[0];
                                                    String month = date.split("-")[1];
                                                    String day = date.split("-")[2];
                                                    String hour = time.split("-")[0];
                                                    String min = time.split("-")[1];
                                                    String sec = time.split("-")[2];
                                                    String timeType = "";
                                                    if(!ss.settings.use24HrFormat.value){
                                                      if(int.parse(hour) >= 12 && int.parse(hour) < 24){
                                                        timeType = "PM";
                                                      } else{
                                                        timeType = "AM";
                                                      }
                                                    }
                                                    if(int.parse(min) < 10){
                                                      min = "0$min";
                                                    }
                                                    if(int.parse(sec) < 10){
                                                      sec = "0$sec";
                                                    }
                                                    if(int.parse(hour) > 12 && !ss.settings.use24HrFormat.value){
                                                      hour = (int.parse(hour) -12).toString();
                                                    }
                                                    finalName = "$month/$day/$year at $hour:$min:$sec $timeType";
                                                  } else{
                                                    finalName = json[index]['name'].toString();
                                                  }
                                                  return ListTile(
                                                    mouseCursor: MouseCursor.defer,
                                                    title: Text(finalName, style: context.theme.textTheme.bodyLarge),
                                                    onTap: () {
                                                      Settings.updateFromMap(json[index]);
                                                      Navigator.of(context).pop();
                                                      showSnackbar("Success", "Settings restored successfully");
                                                    },
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                  ),
                                ),
                              ),
                            )
                        );
                      } catch (e, s) {
                        Logger.error(e);
                        Logger.error(s);
                        Get.back();
                        showSnackbar("Error", "Something went wrong");
                      }
                    } else {
                      Get.back();
                      showSnackbar("Error", "Something went wrong");
                    }
                  },
                  child: Text(
                    "Load Settings",
                    style: TextStyle(
                      color: context.theme.textTheme.bodyMedium!.color,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            if (!kIsWeb)
              Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: context.theme.colorScheme.onPrimary,
                        backgroundColor: context.theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        disabledForegroundColor: context.theme.colorScheme.properOnSurface.withOpacity(0.38),
                        disabledBackgroundColor: context.theme.colorScheme.properOnSurface.withOpacity(0.12),
                        textStyle: context.theme.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.onPrimary),
                      ),
                      onPressed: () async {
                        List<ThemeStruct> allThemes = ThemeStruct.getThemes().where((element) => !element.isPreset).toList();
                        bool errored = false;
                        for (ThemeStruct e in allThemes) {
                          String name = "BlueBubbles Custom Theme - ${e.name}";
                          var response = await http.setTheme(name, e.toMap());
                          if (response.statusCode != 200) {
                            errored = true;
                          }
                        }
                        Get.back();
                        if (allThemes.isEmpty) {
                          showSnackbar(
                            "Notice",
                            "No custom themes found!",
                          );
                        } else if (errored) {
                          showSnackbar(
                            "Error",
                            "Somthing went wrong",
                          );
                        } else {
                          showSnackbar(
                            "Success",
                            "Themes exported successfully to server",
                          );
                        }
                      },
                      child: Text(
                        "Save Theming",
                        style: TextStyle(
                          color: context.theme.colorScheme.onPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: context.theme.colorScheme.onPrimary,
                        backgroundColor: context.theme.colorScheme.properSurface,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: context.theme.colorScheme.primary)
                        ),
                        disabledForegroundColor: context.theme.colorScheme.properOnSurface.withOpacity(0.38),
                        disabledBackgroundColor: context.theme.colorScheme.properOnSurface.withOpacity(0.12),
                        textStyle: context.theme.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                      ),
                      onPressed: () async {
                        var response = await http.getTheme();
                        if (response.statusCode == 200 && response.data.isNotEmpty) {
                          try {
                            List<dynamic> json = response.data['data'];
                            Get.back();
                            showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text("Theme Backups", style: context.theme.textTheme.titleLarge),
                                  backgroundColor: context.theme.colorScheme.properSurface,
                                  content: Container(
                                    constraints: const BoxConstraints(
                                      maxHeight: 300,
                                    ),
                                    child: Container(
                                      width: 300,
                                      height: 300,
                                      constraints: BoxConstraints(
                                        maxHeight: Get.height - 300,
                                      ),
                                      child: StatefulBuilder(
                                          builder: (context, setState) {
                                            return SingleChildScrollView(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Padding(
                                                    padding: const EdgeInsets.all(8.0),
                                                    child: Text("Select the theme you would like to restore", style: context.theme.textTheme.bodyLarge),
                                                  ),
                                                  ListView.builder(
                                                    shrinkWrap: true,
                                                    itemCount: json.length,
                                                    physics: const NeverScrollableScrollPhysics(),
                                                    itemBuilder: (context, index) {
                                                      return ListTile(
                                                        mouseCursor: MouseCursor.defer,
                                                        title: Text(json[index]['name'], style: context.theme.textTheme.bodyLarge),
                                                        onTap: () async {
                                                          if (!json[index].containsKey('data')) {
                                                            return showSnackbar("Error", "This theme was created on the old theming engine and cannot be restored");
                                                          }
                                                          ThemeStruct object = ThemeStruct.fromMap(json[index]);
                                                          object.id = null;
                                                          object.save();
                                                          Navigator.of(context).pop();
                                                          showSnackbar("Success", "Theme restored successfully");
                                                        },
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            );
                                          }
                                      ),
                                    ),
                                  ),
                                )
                            );
                          } catch (e, s) {
                            Logger.error(e);
                            Logger.error(s);
                            Get.back();
                            showSnackbar("Error", "Something went wrong");
                          }
                        } else {
                          Get.back();
                          showSnackbar("Error", "Something went wrong");
                        }
                      },
                      child: Text(
                        "Load Theming",
                        style: TextStyle(
                          color: context.theme.textTheme.bodyMedium!.color,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ]
              ),
            const SizedBox(
              height: 15.0,
            ),
            Text("Load / Save Locally", style: context.theme.textTheme.labelLarge),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Container(color: context.theme.textTheme.labelLarge!.color, height: 0.5),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: context.theme.colorScheme.onPrimary,
                    backgroundColor: context.theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    disabledForegroundColor: context.theme.colorScheme.properOnSurface.withOpacity(0.38),
                    disabledBackgroundColor: context.theme.colorScheme.properOnSurface.withOpacity(0.12),
                    textStyle: context.theme.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.onPrimary),
                  ),
                  onPressed: () async {
                    String directoryPath = "/storage/emulated/0/Download/BlueBubbles-settings-";
                    DateTime now = DateTime.now().toLocal();
                    String filePath = "$directoryPath${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.json";
                    Map<String, dynamic> json = ss.settings.toMap();
                    if (kIsWeb) {
                      final bytes = utf8.encode(jsonEncode(json));
                      final content = base64.encode(bytes);
                      html.AnchorElement(
                          href: "data:application/octet-stream;charset=utf-16le;base64,$content")
                        ..setAttribute("download", filePath.split("/").last)
                        ..click();
                      return;
                    }
                    if (kIsDesktop) {
                      String? _filePath = await FilePicker.platform.saveFile(
                        initialDirectory: (await getDownloadsDirectory())?.path,
                        dialogTitle: 'Choose a location to save this file',
                        fileName: "BlueBubbles-settings-${now.year}${now.month}${now.day}_${now
                            .hour}${now.minute}${now.second}.json",
                        type: FileType.custom,
                        allowedExtensions: ["json"],
                      );
                      if (_filePath == null) {
                        return showSnackbar('Failed', 'You didn\'t select a file path!');
                      }
                      filePath = _filePath;
                    }
                    File file = File(filePath);
                    await file.create(recursive: true);
                    String jsonString = jsonEncode(json);
                    await file.writeAsString(jsonString);
                    Get.back();
                    showSnackbar(
                      "Success",
                      "Settings exported successfully to ${kIsDesktop ? filePath : "downloads folder"}",
                      durationMs: 2000,
                      button: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Get.theme.colorScheme.secondary,
                        ),
                        onPressed: () {
                          Share.file("BlueBubbles Settings", filePath);
                        },
                        child: kIsDesktop ? const SizedBox.shrink() : Text("SHARE", style: TextStyle(color: context.theme.primaryColor)),
                      ),
                    );
                  },
                  child: Text(
                    "Save Settings",
                    style: TextStyle(
                      color: context.theme.colorScheme.onPrimary,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: context.theme.colorScheme.onPrimary,
                    backgroundColor: context.theme.colorScheme.properSurface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: context.theme.colorScheme.primary)
                    ),
                    disabledForegroundColor: context.theme.colorScheme.properOnSurface.withOpacity(0.38),
                    disabledBackgroundColor: context.theme.colorScheme.properOnSurface.withOpacity(0.12),
                    textStyle: context.theme.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                  ),
                  onPressed: () async {
                    final res = await FilePicker.platform
                        .pickFiles(withData: true, type: FileType.custom, allowedExtensions: ["json"]);
                    if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;

                    try {
                      String jsonString = const Utf8Decoder().convert(res.files.first.bytes!);
                      Map<String, dynamic> json = jsonDecode(jsonString);
                      Settings.updateFromMap(json);
                      Get.back();
                      showSnackbar("Success", "Settings restored successfully");
                    } catch (e, s) {
                      Logger.error(e);
                      Logger.error(s);
                      Get.back();
                      showSnackbar("Error", "Something went wrong");
                    }
                  },
                  child: Text(
                    "Load Settings",
                    style: TextStyle(
                      color: context.theme.textTheme.bodyMedium!.color,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            if (!kIsWeb)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: context.theme.colorScheme.onPrimary,
                      backgroundColor: context.theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      disabledForegroundColor: context.theme.colorScheme.properOnSurface.withOpacity(0.38),
                      disabledBackgroundColor: context.theme.colorScheme.properOnSurface.withOpacity(0.12),
                      textStyle: context.theme.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.onPrimary),
                    ),
                    onPressed: () async {
                      List<ThemeStruct> allThemes = ThemeStruct.getThemes().where((element) => !element.isPreset).toList();
                      final List<Map<String, dynamic>> themeData = [];
                      for (ThemeStruct e in allThemes) {
                        themeData.add(e.toMap());
                      }
                      String jsonStr = jsonEncode(themeData);
                      String directoryPath = "/storage/emulated/0/Download/BlueBubbles-theming-";
                      DateTime now = DateTime.now().toLocal();
                      String filePath = "$directoryPath${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.json";
                      if (kIsWeb) {
                        final bytes = utf8.encode(jsonStr);
                        final content = base64.encode(bytes);
                        html.AnchorElement(
                            href: "data:application/octet-stream;charset=utf-16le;base64,$content")
                          ..setAttribute("download", filePath.split("/").last)
                          ..click();
                        return;
                      }
                      if (kIsDesktop) {
                        String? _filePath = await FilePicker.platform.saveFile(
                          initialDirectory: (await getDownloadsDirectory())?.path,
                          dialogTitle: 'Choose a location to save this file',
                          fileName: "BlueBubbles-theming-${now.year}${now.month}${now.day}_${now
                              .hour}${now.minute}${now.second}.json",
                          type: FileType.custom,
                          allowedExtensions: ["json"],
                        );
                        if (_filePath == null) {
                          return showSnackbar('Failed', 'You didn\'t select a file path!');
                        }
                        filePath = _filePath;
                      }
                      File file = File(filePath);
                      await file.create(recursive: true);
                      await file.writeAsString(jsonStr);
                      Get.back();
                      showSnackbar(
                        "Success",
                        "Theming exported successfully to ${kIsDesktop ? filePath : "downloads folder"}",
                        durationMs: 2000,
                        button: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: Get.theme.colorScheme.secondary,
                          ),
                          onPressed: () {
                            Share.file("BlueBubbles Theming", filePath);
                          },
                          child: kIsDesktop ? const SizedBox.shrink() : Text("SHARE", style: TextStyle(color: context.theme.primaryColor)),
                        ),
                      );
                    },
                    child: Text(
                      "Save Theming",
                      style: TextStyle(
                        color: context.theme.colorScheme.onPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: context.theme.colorScheme.onPrimary,
                      backgroundColor: context.theme.colorScheme.properSurface,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: context.theme.colorScheme.primary)
                      ),
                      disabledForegroundColor: context.theme.colorScheme.properOnSurface.withOpacity(0.38),
                      disabledBackgroundColor: context.theme.colorScheme.properOnSurface.withOpacity(0.12),
                      textStyle: context.theme.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                    ),
                    onPressed: () async {
                      final res = await FilePicker.platform
                          .pickFiles(withData: true, type: FileType.custom, allowedExtensions: ["json"]);
                      if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;

                      try {
                        String jsonString = const Utf8Decoder().convert(res.files.first.bytes!);
                        List<dynamic> json = jsonDecode(jsonString);
                        for (var e in json) {
                          ThemeStruct object = ThemeStruct.fromMap(e);
                          if (object.isPreset) continue;
                          object.id = null;
                          object.save();
                        }
                        Get.back();
                        showSnackbar("Success", "Theming restored successfully");
                      } catch (e, s) {
                        Logger.error(e);
                        Logger.error(s);
                        Get.back();
                        showSnackbar("Error", "Something went wrong");
                      }
                    },
                    child: Text(
                      "Load Theming",
                      style: TextStyle(
                        color: context.theme.textTheme.bodyMedium!.color,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
          ]
      ),
    );
  }
}
