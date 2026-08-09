import 'package:bluebubbles/app/layouts/settings/pages/contacts/contacts_management_controller.dart';
import 'package:bluebubbles/app/layouts/settings/pages/contacts/widgets/contacts_expressive_body.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';

/// Material M3 Expressive skin — built on the existing `lib/app/components/m3e/`
/// primitives, following `material_storage_analyzer_panel.dart` as the
/// reference implementation.
class MaterialContactsManagementPanel extends StatelessWidget {
  const MaterialContactsManagementPanel({super.key, required this.controller});

  final ContactsManagementController controller;

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: "Contacts Management",
      initialHeader: null,
      iosSubtitle: context.iosSubtitle,
      materialSubtitle: context.materialSubtitle,
      tileColor: context.tileColor,
      headerColor: context.headerColor,
      bodySlivers: [
        SliverToBoxAdapter(child: ContactsExpressiveBody(controller: controller)),
      ],
    );
  }
}
