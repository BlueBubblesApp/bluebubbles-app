//import 'dart:io';
//
//import 'package:contacts_service/contacts_service.dart';
//import 'package:flutter/material.dart';
//import 'package:path_provider/path_provider.dart';
//import 'package:share_extend/share_extend.dart';
//
///// Share a VCF Card from a Contact Object
//void shareVCFCard(BuildContext context, {@required Contact contact}) async {
//  final Contact _info = contact;
//  if (_info != null)
//    try {
//      var _data = _vcfTemplate(_info);
//      var _vcf = await _createFile(_data);
//      await _readFile();
//      _vcf = await _changeExtenstion(".vcf");
//      if (_vcf != null) {
//        ShareExtend.share(_vcf.path, "file");
//      }
//    } catch (e) {
//      print("Error Creating VCF File $e");
//      return null;
//    }
//}
//
//Future<String> get _localPath async {
//  final directory = await getApplicationDocumentsDirectory();
//  return directory.path;
//}
//
//Future<File> get _localFile async {
//  final path = await _localPath;
//  return File('$path/contact.txt');
//}
//
//Future<String> _readFile() async {
//  try {
//    final file = await _localFile;
//    String contents = await file.readAsString();
//    print("Contents: $contents");
//    return contents;
//  } catch (e) {
//    print(e);
//    return "";
//  }
//}
//
//Future<File> _createFile(String data) async {
//  final file = await _localFile;
//  print("Data: $data");
//  return file.writeAsString('$data');
//}
//
//Future<File> _changeExtenstion(String ext) async {
//  final file = await _localFile;
//  var _newFile = file.renameSync(file.path.replaceAll(".txt", ext));
//  print("New Path: ${_newFile.path}");
//  return _newFile;
//}
//
//String _vcfTemplate(Contact contact) {
//  final Contact _info = contact;
//  try {
//    String str = "";
//    str += "BEGIN:VCARD\n";
//
//    str += "VERSION:4.0\n";
//
//    str += "N:${_info?.familyName};${_info?.givenName};;;\n";
//
//    str += "FN:${(_info?.givenName ?? "") + " " + _info?.familyName}\n";
//
//    if (_info?.company != null && _info.company.isNotEmpty)
//      str += "ORG:${_info?.company}\n";
//
//    if (_info?.jobTitle != null && _info.jobTitle.isNotEmpty)
//      str += "TITLE:${_info?.jobTitle}\n";
//
//    if (_info?.phones != null && _info.phones.isNotEmpty) {
//      int _index = 1;
//      for (var _item in _info.phones) {
//        if (_item != null) {
//          str +=
//              "TEL;PREF=${_index.toString()};TYPE=${_item?.label?.toUpperCase()}:${_item?.value}\n";
//          print("Added => Phone ${_item?.label} | ${_item?.value}");
//        }
//        _index++;
//      }
//    }
//
//    if (_info?.emails != null && _info.emails.isNotEmpty) {
//      int _index = 1;
//      for (var _item in _info.emails) {
//        str +=
//            "EMAIL;PREF=${_index.toString()};TYPE=${_item?.label}:${_item?.value}\n";
//        print("Added => Email ${_item?.label} | ${_item?.value}");
//        _index++;
//      }
//    }
//
//    if (_info?.postalAddresses != null && _info.postalAddresses.isNotEmpty) {
//      int _index = 1;
//      for (var _item in _info.postalAddresses) {
//        str +=
//            "ADR;PREF=${_index.toString()};TYPE=${_item?.label}:;;${_item?.street}\, ;${_item?.city};${_item?.region};${_item?.postcode};${_item?.country}\n";
//        print("Added => Address ${_item?.label}");
//        _index++;
//      }
//    }
//
//    str += "REV:20080424T195243Z\n";
//
//    str += "END:VCARD";
//
//    return str;
//  } catch (e) {
//    print("Error Creating VCF Data $e");
//    return null;
//  }
//}