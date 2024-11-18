class FindMyDevice {
  FindMyDevice({
    required this.deviceModel,
    required this.lowPowerMode,
    required this.passcodeLength,
    required this.itemGroup,
    required this.id,
    required this.batteryStatus,
    required this.audioChannels,
    required this.lostModeCapable,
    required this.snd,
    required this.batteryLevel,
    required this.locationEnabled,
    required this.isConsideredAccessory,
    required this.address,
    required this.location,
    required this.modelDisplayName,
    required this.deviceColor,
    required this.activationLocked,
    required this.rm2State,
    required this.locFoundEnabled,
    required this.nwd,
    required this.deviceStatus,
    required this.remoteWipe,
    required this.fmlyShare,
    required this.thisDevice,
    required this.lostDevice,
    required this.lostModeEnabled,
    required this.deviceDisplayName,
    required this.safeLocations,
    required this.name,
    required this.canWipeAfterLock,
    required this.isMac,
    required this.rawDeviceModel,
    required this.baUuid,
    required this.trackingInfo,
    required this.features,
    required this.deviceDiscoveryId,
    required this.prsId,
    required this.scd,
    required this.locationCapable,
    required this.remoteLock,
    required this.wipeInProgress,
    required this.darkWake,
    required this.deviceWithYou,
    required this.maxMsgChar,
    required this.deviceClass,
    required this.crowdSourcedLocation,
    required this.role,
    required this.lostModeMetadata,
  });

  final String? deviceModel;
  final dynamic lowPowerMode;
  final int? passcodeLength;
  final dynamic itemGroup;
  final String? id;
  final String? batteryStatus;
  final List<dynamic> audioChannels;
  final dynamic lostModeCapable;
  final dynamic snd;
  final double? batteryLevel;
  final dynamic locationEnabled;
  final bool isConsideredAccessory;
  final Address? address;
  final Location? location;
  final String? modelDisplayName;
  final dynamic deviceColor;
  final dynamic activationLocked;
  final int? rm2State;
  final dynamic locFoundEnabled;
  final dynamic nwd;
  final String? deviceStatus;
  final dynamic remoteWipe;
  final dynamic fmlyShare;
  final dynamic thisDevice;
  final dynamic lostDevice;
  final dynamic lostModeEnabled;
  final String? deviceDisplayName;
  final List<SafeLocation> safeLocations;
  final String? name;
  final dynamic canWipeAfterLock;
  final dynamic isMac;
  final String? rawDeviceModel;
  final String? baUuid;
  final dynamic trackingInfo;
  final Map<String, bool?>? features;
  final String? deviceDiscoveryId;
  final String? prsId;
  final dynamic scd;
  final dynamic locationCapable;
  final dynamic remoteLock;
  final dynamic wipeInProgress;
  final dynamic darkWake;
  final dynamic deviceWithYou;
  final int? maxMsgChar;
  final String? deviceClass;
  final dynamic crowdSourcedLocation;
  final Map<String, dynamic>? role;
  final Map<String, dynamic>? lostModeMetadata;

  factory FindMyDevice.fromJson(Map<String, dynamic> json) => FindMyDevice(
    deviceModel: json["deviceModel"],
    lowPowerMode: json["lowPowerMode"],
    passcodeLength: json["passcodeLength"],
    itemGroup: json["itemGroup"],
    id: json["id"],
    batteryStatus: json["batteryStatus"],
    audioChannels: json["audioChannels"] ?? [],
    lostModeCapable: json["lostModeCapable"],
    snd: json["snd"],
    batteryLevel: json["batteryLevel"]?.toDouble(),
    locationEnabled: json["locationEnabled"],
    isConsideredAccessory: json["isConsideredAccessory"] ?? false,
    address: json["address"] == null ? null : Address.fromJson(json["address"]),
    location: json["location"] == null ? null : Location.fromJson(json["location"]),
    modelDisplayName: json["modelDisplayName"],
    deviceColor: json["deviceColor"],
    activationLocked: json["activationLocked"],
    rm2State: json["rm2State"],
    locFoundEnabled: json["locFoundEnabled"],
    nwd: json["nwd"],
    deviceStatus: json["deviceStatus"],
    remoteWipe: json["remoteWipe"],
    fmlyShare: json["fmlyShare"],
    thisDevice: json["thisDevice"],
    lostDevice: json["lostDevice"],
    lostModeEnabled: json["lostModeEnabled"],
    deviceDisplayName: json["deviceDisplayName"],
    safeLocations: json["safeLocations"] == null ? [] : List<SafeLocation>.from(json["safeLocations"].map((x) => SafeLocation.fromJson(x))),
    name: json["name"],
    canWipeAfterLock: json["canWipeAfterLock"],
    isMac: json["isMac"],
    rawDeviceModel: json["rawDeviceModel"],
    baUuid: json["baUUID"],
    trackingInfo: json["trackingInfo"],
    features: json["features"]?.cast<String, bool?>(),
    deviceDiscoveryId: json["deviceDiscoveryId"],
    prsId: json["prsId"],
    scd: json["scd"],
    locationCapable: json["locationCapable"],
    remoteLock: json["remoteLock"],
    wipeInProgress: json["wipeInProgress"],
    darkWake: json["darkWake"],
    deviceWithYou: json["deviceWithYou"],
    maxMsgChar: json["maxMsgChar"],
    deviceClass: json["deviceClass"],
    crowdSourcedLocation: json["crowdSourcedLocation"],
    role: json["role"],
    lostModeMetadata: json["lostModeMetadata"],
  );

  Map<String, dynamic> toJson() => {
    "deviceModel": deviceModel,
    "lowPowerMode": lowPowerMode,
    "passcodeLength": passcodeLength,
    "itemGroup": itemGroup,
    "id": id,
    "batteryStatus": batteryStatus,
    "audioChannels": audioChannels,
    "lostModeCapable": lostModeCapable,
    "snd": snd,
    "batteryLevel": batteryLevel,
    "locationEnabled": locationEnabled,
    "isConsideredAccessory": isConsideredAccessory,
    "address": address?.toJson(),
    "location": location?.toJson(),
    "modelDisplayName": modelDisplayName,
    "deviceColor": deviceColor,
    "activationLocked": activationLocked,
    "rm2State": rm2State,
    "locFoundEnabled": locFoundEnabled,
    "nwd": nwd,
    "deviceStatus": deviceStatus,
    "remoteWipe": remoteWipe,
    "fmlyShare": fmlyShare,
    "thisDevice": thisDevice,
    "lostDevice": lostDevice,
    "lostModeEnabled": lostModeEnabled,
    "deviceDisplayName": deviceDisplayName,
    "safeLocations": safeLocations,
    "name": name,
    "canWipeAfterLock": canWipeAfterLock,
    "isMac": isMac,
    "rawDeviceModel": rawDeviceModel,
    "baUUID": baUuid,
    "trackingInfo": trackingInfo,
    "features": features,
    "deviceDiscoveryId": deviceDiscoveryId,
    "prsId": prsId,
    "scd": scd,
    "locationCapable": locationCapable,
    "remoteLock": remoteLock,
    "wipeInProgress": wipeInProgress,
    "darkWake": darkWake,
    "deviceWithYou": deviceWithYou,
    "maxMsgChar": maxMsgChar,
    "deviceClass": deviceClass,
    "crowdSourcedLocation": crowdSourcedLocation,
  };
}

class Address {
  Address({
    required this.subAdministrativeArea,
    required this.label,
    required this.streetAddress,
    required this.countryCode,
    required this.stateCode,
    required this.administrativeArea,
    required this.streetName,
    required this.formattedAddressLines,
    required this.mapItemFullAddress,
    required this.fullThroroughfare,
    required this.areaOfInterest,
    required this.locality,
    required this.country,
  });

  String? label;

  final String? subAdministrativeArea;
  final String? streetAddress;
  final String? countryCode;
  final String? stateCode;
  final String? administrativeArea;
  final String? streetName;
  final List<String> formattedAddressLines;
  final String? mapItemFullAddress;
  final String? fullThroroughfare;
  final List<dynamic> areaOfInterest;
  final String? locality;
  final String? country;

  String get uniqueValue => (label ?? mapItemFullAddress)!;

  factory Address.fromJson(Map<String, dynamic> json) => Address(
    subAdministrativeArea: json["subAdministrativeArea"],
    label: json["label"],
    streetAddress: json["streetAddress"],
    countryCode: json["countryCode"],
    stateCode: json["stateCode"],
    administrativeArea: json["administrativeArea"],
    streetName: json["streetName"],
    formattedAddressLines: json["formattedAddressLines"]?.cast<String>() ?? <String>[],
    mapItemFullAddress: json["mapItemFullAddress"],
    fullThroroughfare: json["fullThroroughfare"],
    areaOfInterest: json["areaOfInterest"] ?? [],
    locality: json["locality"],
    country: json["country"],
  );

  Map<String, dynamic> toJson() => {
    "subAdministrativeArea": subAdministrativeArea,
    "label": label,
    "streetAddress": streetAddress,
    "countryCode": countryCode,
    "stateCode": stateCode,
    "administrativeArea": administrativeArea,
    "streetName": streetName,
    "formattedAddressLines": formattedAddressLines,
    "mapItemFullAddress": mapItemFullAddress,
    "fullThroroughfare": fullThroroughfare,
    "areaOfInterest": areaOfInterest,
    "locality": locality,
    "country": country,
  };
}

class Location {
  Location({
    required this.positionType,
    required this.verticalAccuracy,
    required this.longitude,
    required this.floorLevel,
    required this.isInaccurate,
    required this.isOld,
    required this.horizontalAccuracy,
    required this.latitude,
    required this.timeStamp,
    required this.altitude,
    required this.locationFinished,
  });

  final String? positionType;
  final int? verticalAccuracy;
  final double? longitude;
  final int? floorLevel;
  final bool? isInaccurate;
  final bool? isOld;
  final double? horizontalAccuracy;
  final double? latitude;
  final int? timeStamp;
  final int? altitude;
  final bool? locationFinished;

  factory Location.fromJson(Map<String, dynamic> json) => Location(
    positionType: json["positionType"],
    verticalAccuracy: json["verticalAccuracy"],
    longitude: json["longitude"]?.toDouble(),
    floorLevel: json["floorLevel"],
    isInaccurate: json["isInaccurate"],
    isOld: json["isOld"],
    horizontalAccuracy: json["horizontalAccuracy"]?.toDouble(),
    latitude: json["latitude"]?.toDouble(),
    timeStamp: json["timeStamp"],
    altitude: json["altitude"],
    locationFinished: json["locationFinished"],
  );

  Map<String, dynamic> toJson() => {
    "positionType": positionType,
    "verticalAccuracy": verticalAccuracy,
    "longitude": longitude,
    "floorLevel": floorLevel,
    "isInaccurate": isInaccurate,
    "isOld": isOld,
    "horizontalAccuracy": horizontalAccuracy,
    "latitude": latitude,
    "timeStamp": timeStamp,
    "altitude": altitude,
    "locationFinished": locationFinished,
  };
}

class SafeLocation {
  SafeLocation({
    required this.type,
    required this.approvalState,
    required this.name,
    required this.identifier,
    required this.location,
    required this.address
  });

  final int? type;
  final int? approvalState;
  final String? name;
  final String identifier;
  final Location location;
  final Address address;


  factory SafeLocation.fromJson(Map<String, dynamic> json) => SafeLocation(
    type: json["type"],
    approvalState: json["approvalState"],
    name: json["name"],
    identifier: json["identifier"],
    location: Location.fromJson(json["location"]),
    address: Address.fromJson(json["address"]),
  );

  Map<String, dynamic> toJson() => {
    "type": type,
    "approvalState": approvalState,
    "name": name,
    "identifier": identifier,
    "location": location.toJson(),
    "address": address.toJson(),
  };
}
