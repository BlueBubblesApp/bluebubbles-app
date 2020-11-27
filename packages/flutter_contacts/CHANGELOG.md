## [0.4.6] - April 29, 2020

* Fixed openExistingContact in Android and in example (@engylemure)

## [0.4.5] - April 26, 2020

* Fixed crashing where activity result coming back from another plugin and not handled (@lidongze91)
* Fixed swift syntax error in UIActivityIndicatorView.init (@sperochon)
* Added new functionality openDeviceContactPicker (@sperochon)
  * Function opens native device contact picker corresponding on each native platform (Android or iOS); user can then search and select a specific contact.
  * Android: Intent.ACTION_PICK
  * iOS: CNContactPickerViewController

## [0.4.4] - April 23, 2020

* Fixed swift function name (@lidongze91)
* Added parameter iOSLocalizedLabels to openContactForm and openExistingContact (@sperochon)

## [0.4.3] - April 22, 2020

* Fixed getContactsForEmail with iOSLocalizedLabels (@pavanbuzz)

## [0.4.2] - April 21, 2020

* Two methods have been added to handle creating and editing contacts with device contact form (@engylemure)

## [0.4.1] - April 21, 2020

* @sperochon
  * Android: retrieve correct custom phone labels
  * iOS: add localizedLabels parameter to avoid labels translations
  * Android: retrieve correct custom phone labels (refactor)
  * iOS: recognize emails predefined labels (work,home,other) when adding a contact to device contacts
  * Fixed issue: birthday not imported (Android only)
  * Fixed issue: birthday not imported (iOS only) and export the same data as Android '--MM-dd' for birthday without year

* @pavanbuzz
  * Get contacts based on matching email available on iOS
  * Fixed contacts_test as it was broken from staging branch
  * Fixed slowness in get contact for iOS 11+
  * Fixed getContacts with phoneQuery to use predicates which are available from iOS 11

## [0.4.0] - March 30, 2020

* Migrated the plugin to android v2 embedding and migrated androidx for example app (@lidongze91)

## [0.3.10] - December 6, 2019

* Expose the raw account type (e.g. "com.google" or "com.skype") and account name on Android (@joachimvalente)
* Added additional labels for work, home, and other for PhoneLabel (@pavanbuzz)
* Added additional labels for work, home, and other for PostalAddress (@pavanbuzz)

## [0.3.9] - November 12, 2019

* Expose androidAccountType as enum in dart (@lidongze91)
  * Only supported for Android.

## [0.3.8] - November 6, 2019

* Added displayName parameter to Contact Constructor (@biswa1751)

## [0.3.7] - November 5, 2019

* Expose account_type from android (@lidongze91)

## [0.3.6] - October 28, 2019

* Added the birthday property in the contact class, display it in the example app (@ZaraclaJ)
* Added missing birthday property in the contact class (@ZaraclaJ)
* Removed redundant equals operator and hashing (@kmccmk9)
* Added toString, equals operator and hashcode (@kmccmk9)

## [0.3.5] - October 17, 2019

* Added `getAvatar()` API to lazily retrieve contact avatars (@dgp1130)
  * Only implemented for Android.

## [0.3.4] - September 21, 2019
  
* Fix Contact.java comparison to guard NPEs (@creativepsyco)

## [0.3.3] - September 12, 2019
  
* Example app, removed references to notes field removed in v0.3.1 (@lukasgit)

## [0.3.2] - September 10, 2019
  
* Fixed swift_version error (@adithyaxx)
* Removed executable file attributes (@creativepsyco)
* Removed references to notes field removed in v0.3.1 (@lukasgit)

## [0.3.1] - September 8, 2019

* Added order by given name, now contacts come sorted from the device (@Tryneeth)
* Return contacts that start with query instead of contains (@dakaugu)
* Removed notes field due to iOS 13 blocking access (@imvm)

## [0.3.0] - August 5th, 2019

* Closed image streams and cursors on Android (@budo385)

## [0.2.9] - July 19th, 2019

* File cleanup and removed .iml references. Use "flutter clean" to clear build files and re-build

## [0.2.8] - June 24th, 2019

* Android add avatar image - was not working.
* Android and iOS - update avatar image.
* Android custom phone label - adding label other then predefined ones sets the label to specified value.
* Android and iOS - on getContacts get the higher resolution image (photoHighResolution). Only when withThumbnails is true. photoHighResolution set to default when getting contact. Default is photoHighResolution = true because if you update the contact after getting, it will update the original size picture.
* Android and iOS - getContactsForPhone(String phone, {bool withThumbnails = true, bool photoHighResolution = true}) - gets the contacts with phone filter.

## [0.2.7] - May 24th, 2019

* Removed path_provider

## [0.2.6] - May 9th, 2019

* Removed share_extend
* Updated example app
* Bug fixes

## [0.2.5] - April 20th, 2019

* Added Notes support, and updateContact for Android fix
* Added Note support for iOS
* Added public method to convert contact to map using the static _toMap
* Updated tests
* Updated example app
* Bug fixes

## [0.2.4] - March 12th, 2019

* Added support for more phone labels
* Bug fixes

## [0.2.3] - March 2nd, 2019

* Added permission handling to example app
* Fixed build errors for Android & iOS

## [0.2.2] - March 1st, 2019

* **Feature:** Update Contact for iOS & Android
* Added updateContact method to contacts_service.dart
* Added updateContact method to SwiftContactsServicePlugin.swift
* Added unit testing for the updateContact method
* Fixed formatting discrepancies in the example app (making code easier to read)
* Fixed formatting discrepancies in contacts_service.dart (making code easier to read)
* AndroidX compatibility fix for example app
* Updated example app to show updateContacts method
* Fixed example app bugs
* Updated PostalAddress.java and Contact.java (wasn't working properly)
* Added updateContact method to ContactsServicePlugin.java

## [0.2.1] - February 21st, 2019

* **Breaking:** Updated dependencies

## [0.2.0] - February 19th, 2019

* **Breaking:** Updated to support AndroidX

## [0.1.1] - January 11th, 2019

* Added Ability to Share VCF Card (@AppleEducate)

## [0.1.0] - January 4th, 2019

* Update pubspec version and maintainer info for Dart Pub
* Add withThumbnails and update example (@trinqk)

## [0.0.9] - October 10th, 2018

* Fix an issue when fetching contacts on Android

## [0.0.8] - August 16th, 2018

* Fix an issue with phones being added to emails on Android
* Update plugin for dart 2

## [0.0.7] - July 10th, 2018

* Fix PlatformException on iOS
* Add a refresh to the contacts list in the sample app when you add a contact
* Return more meaningful errors when addContact() fails on iOS
* Code tidy up

## [0.0.6] - April 13th, 2018

* Add contact thumbnails

## [0.0.5] - April 5th, 2018

* Fix with dart2 compatibility

## [0.0.4] - February 1st, 2018

* Implement deleteContact(Contact c) for Android and iOS

## [0.0.3] - January 31st, 2018

* Implement addContact(Contact c) for Android and iOS

## [0.0.2] - January 30th, 2018

* Now retrieving contacts' prefixes and suffixes

## [0.0.1] - January 30th, 2018

* All contacts can be retrieved
* Contacts matching a string can be retrieved
