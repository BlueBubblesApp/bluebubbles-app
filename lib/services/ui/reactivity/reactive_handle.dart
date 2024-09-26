import 'package:bluebubbles/database/models.dart';
import 'package:get/get.dart';

class ReactiveHandle {
  final Handle handle;

  final Rxn<Contact> _contact = Rxn<Contact>();

  Rxn<Contact> get contact => _contact;

  ReactiveHandle(this.handle, {
    Contact? contact
  }) {
    _contact.value = contact;
  }

  setContact(Contact? contact) {
    _contact.value = contact;
    handle.contactRelation.target = contact;
  }

  factory ReactiveHandle.fromHandle(Handle handle) {
    return ReactiveHandle(
      handle,
      contact: handle.contact
    );
  }
}