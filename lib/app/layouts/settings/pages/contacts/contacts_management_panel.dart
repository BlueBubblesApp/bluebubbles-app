import 'package:bluebubbles/app/layouts/settings/pages/contacts/contacts_management_controller.dart';
import 'package:bluebubbles/app/layouts/settings/pages/contacts/cupertino_contacts_management_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/contacts/material_contacts_management_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/contacts/samsung_contacts_management_panel.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Entry point for the Contacts Management settings page. Owns the
/// controller's lifecycle directly (single global instance, following
/// `StorageAnalyzerPanel`'s pattern) since nothing else needs it.
class ContactsManagementPanel extends StatefulWidget {
  const ContactsManagementPanel({super.key});

  @override
  State<ContactsManagementPanel> createState() => _ContactsManagementPanelState();
}

class _ContactsManagementPanelState extends State<ContactsManagementPanel> {
  late final controller = Get.put(ContactsManagementController());

  @override
  void dispose() {
    Get.delete<ContactsManagementController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeSwitcher(
      iOSSkin: CupertinoContactsManagementPanel(controller: controller),
      materialSkin: MaterialContactsManagementPanel(controller: controller),
      samsungSkin: SamsungContactsManagementPanel(controller: controller),
    );
  }
}
