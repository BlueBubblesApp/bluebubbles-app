
# contacts_service  
[![pub package](https://img.shields.io/pub/v/contacts_service.svg)](https://pub.dartlang.org/packages/contacts_service)
[![Build Status](https://travis-ci.com/lukasgit/flutter_contacts.svg?branch=master)](https://travis-ci.com/lukasgit/flutter_contacts)
[![Coverage Status](https://coveralls.io/repos/github/clovisnicolas/flutter_contacts/badge.svg?branch=master)](https://coveralls.io/github/clovisnicolas/flutter_contacts?branch=master)

A Flutter plugin to access and manage the device's contacts.  
  
## Usage  
  
To use this plugin, add `contacts_service` as a [dependency in your `pubspec.yaml` file](https://flutter.io/platform-plugins/).  
For example:  
```yaml  
dependencies:  
    contacts_service: ^0.4.6
```  
  
## Permissions  
### Android  
Add the following permissions to your AndroidManifest.xml:  
  
```xml  
<uses-permission android:name="android.permission.READ_CONTACTS" />  
<uses-permission android:name="android.permission.WRITE_CONTACTS" />  
```  
### iOS
Set the `NSContactsUsageDescription` in your `Info.plist` file  
  
```xml  
<key>NSContactsUsageDescription</key>  
<string>This app requires contacts access to function properly.</string>  
```  

**Note**  
`contacts_service` does not handle the process of asking and checking for permissions. To check and request user permission to access contacts, try using the following plugins: [flutter_simple_permissions](https://github.com/AppleEducate/flutter_simple_permissions)  or [permission_handler](https://pub.dartlang.org/packages/permission_handler).
  
If you do not request user permission or have it granted, the application will fail. For testing purposes, you can manually set the permissions for your test app in Settings for your app on the device that you are using. For Android, go to "Settings" - "Apps" - select your test app - "Permissions" - then turn "on" the slider for contacts.   
  
## Example  

```dart  
// Import package  
import 'package:contacts_service/contacts_service.dart';  
  
// Get all contacts on device
Iterable<Contact> contacts = await ContactsService.getContacts();  

// Get all contacts without thumbnail (faster)
Iterable<Contact> contacts = await ContactsService.getContacts(withThumbnails: false);

// Android only: Get thumbnail for an avatar afterwards (only necessary if `withThumbnails: false` is used)
Uint8List avatar = await ContactsService.getAvatar(contact);
  
// Get contacts matching a string
Iterable<Contact> johns = await ContactsService.getContacts(query : "john");

// Add a contact  
// The contact must have a firstName / lastName to be successfully added  
await ContactsService.addContact(newContact);  
  
// Delete a contact
// The contact must have a valid identifier
await ContactsService.deleteContact(contact);  

// Update a contact
// The contact must have a valid identifier
await ContactsService.updateContact(contact);

// Usage of the native device form for creating a Contact
// Throws a error if the Form could not be open or the Operation is canceled by the User
await ContactsService.openContactForm();

// Usage of the native device form for editing a Contact
// The contact must have a valid identifier
// Throws a error if the Form could not be open or the Operation is canceled by the User
await ContactsService.openExistingContact(contact);

```  

**Contact Model**
```dart
// Name
String displayName, givenName, middleName, prefix, suffix, familyName;

// Company
String company, jobTitle;

// Email addresses
Iterable<Item> emails = [];

// Phone numbers
Iterable<Item> phones = [];

// Post addresses
Iterable<PostalAddress> postalAddresses = [];

// Contact avatar/thumbnail
Uint8List avatar;

```
  
![Example](doc/example.gif "Example screenshot")  
  
## Contributions

Contributions are welcome! If you find a bug or want a feature, please fill an issue.

If you want to contribute code please create a pull request under the staging branch.

## Credits

Heavily inspired from rt2zz's react native [plugin](https://github.com/rt2zz/react-native-contacts)
