class StructuredName {
  StructuredName({
    required this.namePrefix,
    required this.givenName,
    required this.middleName,
    required this.familyName,
    required this.nameSuffix,
  });

  static StructuredName? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    return StructuredName(
      namePrefix: map['namePrefix'] as String,
      givenName: map['givenName'] as String,
      middleName: map['middleName'] as String,
      familyName: map['familyName'] as String,
      nameSuffix: map['nameSuffix'] as String,
    );
  }

  Map<String, String> toMap() => {
    "namePrefix": namePrefix,
    "givenName": givenName,
    "middleName": middleName,
    "familyName": familyName,
    "nameSuffix": nameSuffix,
  };

  final String namePrefix;
  final String givenName;
  final String middleName;
  final String familyName;
  final String nameSuffix;
}