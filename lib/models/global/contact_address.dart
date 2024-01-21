enum ContactAddressType {
  phone,
  email
}

class ContactAddress {
  final ContactAddressType type;
  final String address;
  final String? label;

  ContactAddress({required this.type, required this.address, this.label});

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'address': address,
      'label': label,
    };
  }

  static ContactAddress fromMap(Map<String, dynamic> map) {
    return ContactAddress(
      type: ContactAddressType.values.firstWhere((element) => element.name == map['type']),
      address: map['address'],
      label: map['label'],
    );
  }

  static bool listContainsAddress(List<ContactAddress> list, String item) {
    for (ContactAddress current in list) {
      if (current.address == item) {
        return true;
      }
    }

    return false;
  }
}