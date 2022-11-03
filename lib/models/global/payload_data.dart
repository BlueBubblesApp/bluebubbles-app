class PayloadData {
  PayloadData({
    required this.objects,
  });

  List<dynamic> objects;

  factory PayloadData.fromJson(Map<String, dynamic> json) => PayloadData(
    objects: json["objects"] ?? [],
  );

  Map<String, dynamic> toJson() => {
    "objects": objects,
  };
}

dynamic replaceDollar<T>(T element) {
  // if list, traverse thru each element
  if (element is List) {
    final newList = [];
    for (dynamic item in element) {
      newList.add(replaceDollar(item));
    }
    return newList;
  // if map, traverse thru each key & value
  } else if (element is Map) {
    final newMap = {};
    for (MapEntry item in element.entries) {
      newMap[replaceDollar(item.key)] = replaceDollar(item.value);
    }
    return newMap;
  // only replace $ at beginning of string
  } else if (element is String) {
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
      return objects[element["UID"]];
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
        if (item.value is Map) {
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