import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PayloadData {
  PayloadData({
    required this.type,
    this.urlData,
    this.appData,
  });

  PayloadType type;
  List<UrlPreviewData>? urlData;
  List<iMessageAppData>? appData;

  factory PayloadData.fromJson(dynamic json) {
    if (json is Map) {
      return PayloadData(
        type: PayloadType.values[json["type"]],
        urlData: json["urlData"]?.map((e) => UrlPreviewData.fromJson(e)).toList().cast<UrlPreviewData>(),
        appData: json["appData"]?.map((e) => iMessageAppData.fromJson(e)).toList().cast<iMessageAppData>(),
      );
    } else {
      List data = [];
      final sanitized = replaceDollar(json);
      if (sanitized.first["objects"][1] is Map && sanitized.first["objects"][1].containsKey("NS.keys")) {
        data = extractUIDs(sanitized, []);
        return PayloadData(
          type: PayloadType.app,
          appData: data.map((e) => iMessageAppData.fromJson(Map<String, dynamic>.from(e))).toList(),
        );
      } else {
        for (Map m in sanitized) {
          final objects = m['objects'];
          data.add(extractUIDs(objects[2], objects));
        }
        return PayloadData(
          type: PayloadType.url,
          urlData: data.map((e) => UrlPreviewData.fromJson(Map<String, dynamic>.from(e))).toList(),
        );
      }
    }
  }

  Map<String, dynamic> toJson() => {
    "type": type.index,
    "urlData": urlData?.map((e) => e.toJson()).toList(),
    "appData": appData?.map((e) => e.toJson()).toList(),
  };
}

class UrlPreviewData {
  UrlPreviewData({
    this.imageMetadata,
    this.itemType,
    this.videoMetadata,
    this.iconMetadata,
    this.originalUrl,
    this.url,
    this.title,
    this.summary,
    this.siteName,
  });

  MediaMetadata? imageMetadata;
  MediaMetadata? videoMetadata;
  MediaMetadata? iconMetadata;
  String? itemType;
  String? originalUrl;
  String? url;
  String? title;
  String? summary;
  String? siteName;

  factory UrlPreviewData.fromJson(Map<String, dynamic> json) => UrlPreviewData(
    imageMetadata: json["imageMetadata"] == null
        ? (json["specialization"]?["artwork"] != null ? MediaMetadata(size: const Size.square(1), url: json["specialization"]?["artwork"]?["NS.relative"]) : null)
        : MediaMetadata.fromJson(Map<String, dynamic>.from(json["imageMetadata"])),
    videoMetadata: json["videoMetadata"] == null ? null : MediaMetadata.fromJson(Map<String, dynamic>.from(json["videoMetadata"])),
    iconMetadata: json["iconMetadata"] == null ? null : MediaMetadata.fromJson(Map<String, dynamic>.from(json["iconMetadata"])),
    itemType: json["itemType"],
    originalUrl: json["originalURL"]?["NS.relative"],
    url: json["URL"]?["NS.relative"],
    title: json["title"] ?? json["specialization"]?["name"],
    summary: json["summary"] ?? json["specialization"]?["album"],
    siteName: json["siteName"],
  );

  Map<String, dynamic> toJson() => {
    "imageMetadata": imageMetadata?.toJson(),
    "videoMetadata": videoMetadata?.toJson(),
    "iconMetadata": iconMetadata?.toJson(),
    "itemType": itemType,
    "originalURL": {
      "NS.relative": originalUrl
    },
    "URL": {
      "NS.relative": url,
    },
    "title": title,
    "summary": summary,
    "siteName": siteName,
  };
}

class MediaMetadata {
  MediaMetadata({
    this.size,
    this.url,
  });

  Size? size;
  String? url;

  factory MediaMetadata.fromJson(Map<String, dynamic> json) => MediaMetadata(
    size: json["size"] == null ? Size.zero : Size(double.parse(json["size"].split(",").first.toString().numericOnly()), double.parse(json["size"].split(",").last.toString().numericOnly())),
    url: json["URL"]?["NS.relative"],
  );

  Map<String, dynamic> toJson() => {
    "size": size.toString(),
    "URL": {
      "NS.relative": url,
    },
  };
}

// ignore: camel_case_types
class iMessageAppData {
  iMessageAppData({
    this.appName,
    this.ldText,
    this.userInfo,
    this.url,
  });

  String? appName;
  String? ldText;
  String? url;
  UserInfo? userInfo;

  factory iMessageAppData.fromJson(Map<String, dynamic> json) => iMessageAppData(
    appName: json["an"],
    ldText: json["ldtext"],
    userInfo: json["userInfo"] == null ? null : UserInfo.fromJson(Map<String, dynamic>.from(json["userInfo"])),
    url: json["URL"]?["NS.relative"],
  );

  Map<String, dynamic> toJson() => {
    "an": appName,
    "ldtext": ldText,
    "URL": {
      "NS.relative": url,
    },
    "userInfo": userInfo?.toJson(),
  };
}

class UserInfo {
  UserInfo({
    this.imageSubtitle,
    this.imageTitle,
    this.caption,
    this.secondarySubcaption,
    this.tertiarySubcaption,
    this.subcaption,
  });

  String? imageSubtitle;
  String? imageTitle;
  String? caption;
  String? secondarySubcaption;
  String? tertiarySubcaption;
  String? subcaption;

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
    imageSubtitle: json["image-subtitle"],
    imageTitle: json["image-title"],
    caption: json["caption"],
    secondarySubcaption: json["secondary-subcaption"],
    tertiarySubcaption: json["tertiary-subcaption"],
    subcaption: json["subcaption"],
  );

  Map<String, dynamic> toJson() => {
    "image-subtitle": imageSubtitle,
    "image-title": imageTitle,
    "caption": caption,
    "secondary-subcaption": secondarySubcaption,
    "tertiary-subcaption": tertiarySubcaption,
    "subcaption": subcaption,
  };
}

dynamic replaceDollar<T>(T element, {bool isValue = false}) {
  // if list, traverse thru each element
  if (element is List) {
    final newList = [];
    for (dynamic item in element) {
      newList.add(replaceDollar(item, isValue: true));
    }
    return newList;
  // if map, traverse thru each key & value
  } else if (element is Map) {
    final newMap = {};
    for (MapEntry item in element.entries) {
      newMap[replaceDollar(item.key)] = replaceDollar(item.value, isValue: true);
    }
    return newMap;
  // only replace $ at beginning of string
  } else if (element is String && !isValue) {
    if (element.startsWith("\$")) {
      element = element.replaceFirst("\$", "") as T;
    }
    return element;
  }
  // we don't care
  return element;
}

dynamic extractUIDs<T>(T element, List objects) {
  // if list, traverse thru each element and extract data
  if (element is List) {
    final newList = [];
    for (dynamic item in element) {
      newList.add(extractUIDs(item, objects));
    }
    return newList;
  } else if (element is Map) {
    // if map is {"UID": int}, return the associated object and replace the map
    if (element["UID"] != null) {
      var item = objects[element["UID"]];
      if (item is Map || item is List) {
        item = extractUIDs(item, objects);
      }
      return item;
    // if map is nested bplist, extract the data
    } else if (element["archiver"] == "NSKeyedArchiver") {
      // nested bplist will have its own objects
      objects = element['objects'];
      // find keys and values and create new map with data
      final nsKeys = objects[1]["NS.keys"].map((e) => e["UID"]).toList();
      final nsObjects = objects[1]["NS.objects"].map((e) => e["UID"]).toList();
      var data = {};
      for (int i = 0; i < nsKeys.length; i++) {
        data[objects[nsKeys[i]]] = objects[nsObjects[i]];
      }
      data = extractUIDs(data, objects);
      return data;
    // if map is {"NS.keys": [...], "NS.objects": [...], ...}
    } else if (element.containsKey("NS.keys") && element.containsKey("NS.objects")) {
      // fins keys and values from original objects
      final nsKeys = element["NS.keys"].map((e) => e["UID"]).toList();
      final nsObjects = element["NS.objects"].map((e) => e["UID"]).toList();
      // keep the other data items
      var data = element;
      data.remove("NS.keys");
      data.remove("NS.objects");
      for (int i = 0; i < nsKeys.length; i++) {
        data[objects[nsKeys[i]]] = objects[nsObjects[i]];
      }
      data = extractUIDs(data, objects);
      return data;
    // if regular map, extract data from any values
    } else {
      final newMap = {};
      for (MapEntry item in element.entries) {
        if (item.value is Map || item.value is List) {
          newMap[item.key] = extractUIDs(item.value, objects);
        } else {
          newMap.addEntries([item]);
        }
      }
      return newMap;
    }
  }
  // we don't care
  return element;
}