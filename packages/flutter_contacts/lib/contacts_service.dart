import 'dart:async';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:quiver/core.dart';

export 'share.dart';

class ContactsService {
  static const MethodChannel _channel =
      MethodChannel('github.com/clovisnicolas/flutter_contacts');

  /// Fetches all contacts, or when specified, the contacts with a name
  /// matching [query]
  static Future<Iterable<Contact>> getContacts(
      {String query,
      bool withThumbnails = true,
      bool photoHighResolution = true,
      bool orderByGivenName = true,
      bool iOSLocalizedLabels = true}) async {
    Iterable contacts =
        await _channel.invokeMethod('getContacts', <String, dynamic>{
      'query': query,
      'withThumbnails': withThumbnails,
      'photoHighResolution': photoHighResolution,
      'orderByGivenName': orderByGivenName,
      'iOSLocalizedLabels': iOSLocalizedLabels,
    });
    return contacts.map((m) => Contact.fromMap(m));
  }

  /// Fetches all contacts, or when specified, the contacts with the phone
  /// matching [phone]
  static Future<Iterable<Contact>> getContactsForPhone(String phone,
      {bool withThumbnails = true,
      bool photoHighResolution = true,
      bool orderByGivenName = true,
      bool iOSLocalizedLabels = true}) async {
    if (phone == null || phone.isEmpty) return Iterable.empty();

    Iterable contacts =
        await _channel.invokeMethod('getContactsForPhone', <String, dynamic>{
      'phone': phone,
      'withThumbnails': withThumbnails,
      'photoHighResolution': photoHighResolution,
      'orderByGivenName': orderByGivenName,
      'iOSLocalizedLabels': iOSLocalizedLabels,
    });
    return contacts.map((m) => Contact.fromMap(m));
  }

  /// Fetches all contacts, or when specified, the contacts with the email
  /// matching [email]
  /// Works only on iOS
  static Future<Iterable<Contact>> getContactsForEmail(String email,
      {bool withThumbnails = true,
        bool photoHighResolution = true,
        bool orderByGivenName = true,
        bool iOSLocalizedLabels = true}) async {
    Iterable contacts = await _channel.invokeMethod('getContactsForEmail',<String,dynamic>{
      'email': email,
      'withThumbnails': withThumbnails,
      'photoHighResolution': photoHighResolution,
      'orderByGivenName': orderByGivenName,
      'iOSLocalizedLabels': iOSLocalizedLabels,
    });
    return contacts.map((m) => Contact.fromMap(m));
  }

  /// Loads the avatar for the given contact and returns it. If the user does
  /// not have an avatar, then `null` is returned in that slot. Only implemented
  /// on Android.
  static Future<Uint8List> getAvatar(
      final Contact contact, {final bool photoHighRes = true}) =>
      _channel.invokeMethod('getAvatar', <String, dynamic>{
        'contact': Contact._toMap(contact),
        'photoHighResolution': photoHighRes,
      });

  /// Adds the [contact] to the device contact list
  static Future addContact(Contact contact) =>
      _channel.invokeMethod('addContact', Contact._toMap(contact));

  /// Deletes the [contact] if it has a valid identifier
  static Future deleteContact(Contact contact) =>
      _channel.invokeMethod('deleteContact', Contact._toMap(contact));

  /// Updates the [contact] if it has a valid identifier
  static Future updateContact(Contact contact) =>
      _channel.invokeMethod('updateContact', Contact._toMap(contact));

  static Future<Contact> openContactForm({bool iOSLocalizedLabels = true}) async {
    dynamic result = await _channel.invokeMethod('openContactForm',<String,dynamic>{
      'iOSLocalizedLabels': iOSLocalizedLabels,
    });
   return _handleFormOperation(result);
  }

  static Future<Contact> openExistingContact(Contact contact, {bool iOSLocalizedLabels = true}) async {
   dynamic result = await _channel.invokeMethod('openExistingContact',<String,dynamic>{
     'contact': Contact._toMap(contact),
     'iOSLocalizedLabels': iOSLocalizedLabels,
   }, );
   return _handleFormOperation(result);
  }

  // Displays the device/native contact picker dialog and returns the contact selected by the user
  static Future<Contact> openDeviceContactPicker({bool iOSLocalizedLabels = true}) async {
    dynamic result = await _channel.invokeMethod('openDeviceContactPicker',<String,dynamic>{
      'iOSLocalizedLabels': iOSLocalizedLabels,
    });
    // result contains either :
    // - an Iterable of contacts containing 0 or 1 contact
    // - a FormOperationErrorCode value
    if (result is Iterable) {
      if (result.isEmpty) {
        return null;
      }
      result = result.first;
    }
    return _handleFormOperation(result);
  }

  static Contact _handleFormOperation(dynamic result) {
    if(result is int) {
      switch (result) {
        case 1:
          throw FormOperationException(errorCode: FormOperationErrorCode.FORM_OPERATION_CANCELED);
        case 2:
          throw FormOperationException(errorCode: FormOperationErrorCode.FORM_COULD_NOT_BE_OPEN);
        default:
          throw FormOperationException(errorCode: FormOperationErrorCode.FORM_OPERATION_UNKNOWN_ERROR);
      }
    } else if(result is Map) {
      return Contact.fromMap(result);
    } else {
      throw FormOperationException(errorCode: FormOperationErrorCode.FORM_OPERATION_UNKNOWN_ERROR);
    }
  }
}

class FormOperationException implements Exception {
  final FormOperationErrorCode errorCode;

  const FormOperationException({this.errorCode});
   String toString() => 'FormOperationException: $errorCode';
}

enum FormOperationErrorCode {
  FORM_OPERATION_CANCELED,
  FORM_COULD_NOT_BE_OPEN,
  FORM_OPERATION_UNKNOWN_ERROR
}


class Contact {
  Contact({
    this.displayName,
    this.givenName,
    this.middleName,
    this.prefix,
    this.suffix,
    this.familyName,
    this.company,
    this.jobTitle,
    this.emails,
    this.phones,
    this.postalAddresses,
    this.avatar,
    this.birthday,
    this.androidAccountType,
    this.androidAccountTypeRaw,
    this.androidAccountName,
  });

  String identifier, displayName, givenName, middleName, prefix, suffix, familyName, company, jobTitle;
  String androidAccountTypeRaw, androidAccountName;
  AndroidAccountType androidAccountType;
  Iterable<Item> emails = [];
  Iterable<Item> phones = [];
  Iterable<PostalAddress> postalAddresses = [];
  Uint8List avatar;
  DateTime birthday;

  String initials() {
    return ((this.givenName?.isNotEmpty == true ? this.givenName[0] : "") +
            (this.familyName?.isNotEmpty == true ? this.familyName[0] : ""))
        .toUpperCase();
  }

  Contact.fromMap(Map m) {
    identifier = m["identifier"];
    displayName = m["displayName"];
    givenName = m["givenName"];
    middleName = m["middleName"];
    familyName = m["familyName"];
    prefix = m["prefix"];
    suffix = m["suffix"];
    company = m["company"];
    jobTitle = m["jobTitle"];
    androidAccountTypeRaw = m["androidAccountType"];
    androidAccountType = accountTypeFromString(androidAccountTypeRaw);
    androidAccountName = m["androidAccountName"];
    emails = (m["emails"] as Iterable)?.map((m) => Item.fromMap(m));
    phones = (m["phones"] as Iterable)?.map((m) => Item.fromMap(m));
    postalAddresses = (m["postalAddresses"] as Iterable)
        ?.map((m) => PostalAddress.fromMap(m));
    avatar = m["avatar"];
    try {
      birthday = DateTime.parse(m["birthday"]);
    } catch (e) {
      birthday = null;
    }
  }

  static Map _toMap(Contact contact) {
    var emails = [];
    for (Item email in contact.emails ?? []) {
      emails.add(Item._toMap(email));
    }
    var phones = [];
    for (Item phone in contact.phones ?? []) {
      phones.add(Item._toMap(phone));
    }
    var postalAddresses = [];
    for (PostalAddress address in contact.postalAddresses ?? []) {
      postalAddresses.add(PostalAddress._toMap(address));
    }

    final birthday = contact.birthday == null
        ? null
        : "${contact.birthday.year.toString()}-${contact.birthday.month.toString().padLeft(2, '0')}-${contact.birthday.day.toString().padLeft(2, '0')}";

    return {
      "identifier": contact.identifier,
      "displayName": contact.displayName,
      "givenName": contact.givenName,
      "middleName": contact.middleName,
      "familyName": contact.familyName,
      "prefix": contact.prefix,
      "suffix": contact.suffix,
      "company": contact.company,
      "jobTitle": contact.jobTitle,
      "androidAccountType": contact.androidAccountTypeRaw,
      "androidAccountName": contact.androidAccountName,
      "emails": emails,
      "phones": phones,
      "postalAddresses": postalAddresses,
      "avatar": contact.avatar,
      "birthday": birthday
    };
  }

  Map toMap() {
    return Contact._toMap(this);
  }

  /// The [+] operator fills in this contact's empty fields with the fields from [other]
  operator +(Contact other) => Contact(
      givenName: this.givenName ?? other.givenName,
      middleName: this.middleName ?? other.middleName,
      prefix: this.prefix ?? other.prefix,
      suffix: this.suffix ?? other.suffix,
      familyName: this.familyName ?? other.familyName,
      company: this.company ?? other.company,
      jobTitle: this.jobTitle ?? other.jobTitle,
      androidAccountType: this.androidAccountType ?? other.androidAccountType,
      androidAccountName: this.androidAccountName ?? other.androidAccountName,
      emails: this.emails == null
          ? other.emails
          : this.emails.toSet().union(other.emails?.toSet() ?? Set()).toList(),
      phones: this.phones == null
          ? other.phones
          : this.phones.toSet().union(other.phones?.toSet() ?? Set()).toList(),
      postalAddresses: this.postalAddresses == null
          ? other.postalAddresses
          : this
              .postalAddresses
              .toSet()
              .union(other.postalAddresses?.toSet() ?? Set())
              .toList(),
      avatar: this.avatar ?? other.avatar,
      birthday: this.birthday ?? other.birthday,
    );

  /// Returns true if all items in this contact are identical.
  @override
  bool operator ==(Object other) {
    return other is Contact &&
        this.avatar == other.avatar &&
        this.company == other.company &&
        this.displayName == other.displayName &&
        this.givenName == other.givenName &&
        this.familyName == other.familyName &&
        this.identifier == other.identifier &&
        this.jobTitle == other.jobTitle &&
        this.androidAccountType == other.androidAccountType &&
        this.androidAccountName == other.androidAccountName &&
        this.middleName == other.middleName &&
        this.prefix == other.prefix &&
        this.suffix == other.suffix &&
        this.birthday == other.birthday &&
        DeepCollectionEquality.unordered().equals(this.phones, other.phones) &&
        DeepCollectionEquality.unordered().equals(this.emails, other.emails) &&
        DeepCollectionEquality.unordered()
            .equals(this.postalAddresses, other.postalAddresses);
  }

  @override
  int get hashCode {
    return hashObjects([
      this.company,
      this.displayName,
      this.familyName,
      this.givenName,
      this.identifier,
      this.jobTitle,
      this.androidAccountType,
      this.androidAccountName,
      this.middleName,
      this.prefix,
      this.suffix,
      this.birthday,
    ].where((s) => s != null));
  }

  AndroidAccountType accountTypeFromString(String androidAccountType) {
    if (androidAccountType == null) {
      return null;
    }
    if (androidAccountType.startsWith("com.google")) {
      return AndroidAccountType.google;
    } else if (androidAccountType.startsWith("com.whatsapp")) {
      return AndroidAccountType.whatsapp;
    } else if (androidAccountType.startsWith("com.facebook")) {
      return AndroidAccountType.facebook;
    }
    /// Other account types are not supported on Android
    /// such as Samsung, htc etc...
    return AndroidAccountType.other;
  }
}

class PostalAddress {
  PostalAddress(
      {this.label,
      this.street,
      this.city,
      this.postcode,
      this.region,
      this.country});
  String label, street, city, postcode, region, country;

  PostalAddress.fromMap(Map m) {
    label = m["label"];
    street = m["street"];
    city = m["city"];
    postcode = m["postcode"];
    region = m["region"];
    country = m["country"];
  }

  @override
  bool operator ==(Object other) {
    return other is PostalAddress &&
        this.city == other.city &&
        this.country == other.country &&
        this.label == other.label &&
        this.postcode == other.postcode &&
        this.region == other.region &&
        this.street == other.street;
  }

  @override
  int get hashCode {
    return hashObjects([
      this.label,
      this.street,
      this.city,
      this.country,
      this.region,
      this.postcode,
    ].where((s) => s != null));
  }

  static Map _toMap(PostalAddress address) => {
        "label": address.label,
        "street": address.street,
        "city": address.city,
        "postcode": address.postcode,
        "region": address.region,
        "country": address.country
      };

  @override
  String toString() {
    String finalString = "";
    if (this.street != null) {
      finalString += this.street;
    }
    if (this.city != null) {
      if (finalString.isNotEmpty) {
        finalString += ", " + this.city;
      } else {
        finalString += this.city;
      }
    }
    if (this.region != null) {
      if (finalString.isNotEmpty) {
        finalString += ", " + this.region;
      } else {
        finalString += this.region;
      }
    }
    if (this.postcode != null) {
      if (finalString.isNotEmpty) {
        finalString += " " + this.postcode;
      } else {
        finalString += this.postcode;
      }
    }
    if (this.country != null) {
      if (finalString.isNotEmpty) {
        finalString += ", " + this.country;
      } else {
        finalString += this.country;
      }
    }
    return finalString;
  }
}

/// Item class used for contact fields which only have a [label] and
/// a [value], such as emails and phone numbers
class Item {
  Item({this.label, this.value});

  String label, value;

  Item.fromMap(Map m) {
    label = m["label"];
    value = m["value"];
  }

  @override
  bool operator ==(Object other) {
    return other is Item &&
        this.label == other.label &&
        this.value == other.value;
  }

  @override
  int get hashCode => hash2(label ?? "", value ?? "");

  static Map _toMap(Item i) => {"label": i.label, "value": i.value};
}

enum AndroidAccountType {
  facebook,
  google,
  whatsapp,
  other
}
