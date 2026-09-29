import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/services/backend/interfaces/chat_interface.dart';
import 'package:bluebubbles/utils/string_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slugify/slugify.dart';

class _ParticipantContact {
  final String address;
  final String displayName;
  const _ParticipantContact({required this.address, required this.displayName});
}

void showAddParticipant(BuildContext context, Chat chat) {
  final TextEditingController participantController = TextEditingController();
  showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          actions: [
            TextButton(
              child: Text("Cancel",
                  style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            ),
            TextButton(
              child: Text("Pick Contact",
                  style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
              onPressed: () async {
                final contacts = <_ParticipantContact>[];
                final cache = [];
                String slugText(String text) {
                  return slugify(text, delimiter: '').toString().replaceAll('-', '');
                }

                final allContacts = await ContactsSvcV2.getAllContacts();
                for (ContactV2 contact in allContacts) {
                  // ContactV2 stores all addresses (phones and emails) in a single list
                  for (String address in contact.addresses) {
                    String cleansed = slugText(address);

                    if (!cache.contains(cleansed)) {
                      cache.add(cleansed);
                      contacts.add(_ParticipantContact(address: address, displayName: contact.displayName));
                    }
                  }
                }
                contacts.sort((c1, c2) => c1.displayName.compareTo(c2.displayName));
                _ParticipantContact? selected;
                await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                          title: Text("Pick Contact", style: context.theme.textTheme.titleLarge),
                          backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
                          content: SingleChildScrollView(
                            child: SizedBox(
                              width: double.maxFinite,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text("Select the contact you would like to add"),
                                  ),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight: context.mediaQuery.size.height * 0.4,
                                    ),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: contacts.length,
                                      findChildIndexCallback: (key) => findChildIndexByKey(
                                          contacts, key, (item) => "${item.address}-${item.displayName}"),
                                      itemBuilder: (context, index) {
                                        return ListTile(
                                          key: ValueKey("${contacts[index].address}-${contacts[index].displayName}"),
                                          mouseCursor: MouseCursor.defer,
                                          title: Text(contacts[index].displayName),
                                          subtitle: Text(contacts[index].address),
                                          onTap: () {
                                            selected = contacts[index];
                                            Navigator.of(context).pop();
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ));
                if (selected?.address != null) {
                  if (!selected!.address.isEmail) {
                    participantController.text = cleansePhoneNumber(selected!.address);
                  } else {
                    participantController.text = selected!.address;
                  }
                }
              },
            ),
            TextButton(
              child: Text("OK",
                  style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
              onPressed: () async {
                if (participantController.text.isEmpty ||
                    (!participantController.text.isEmail && !participantController.text.isPhoneNumber)) {
                  showSnackbar("Error", "Enter a valid address!", type: SnackbarType.error);
                  return;
                }
                showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
                        title: Text(
                          "Adding ${participantController.text}...",
                          style: context.theme.textTheme.titleLarge,
                        ),
                        content: SizedBox(
                          height: 70,
                          child: Center(
                            child: CircularProgressIndicator(
                              backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                            ),
                          ),
                        ),
                      );
                    });
                final response = await HttpSvc.chat.modifyParticipant("add", chat.guid, participantController.text);
                if (response.statusCode == 200) {
                  // Sync the updated chat (with the new participant) to the DB
                  // and propagate the changes to ChatState so the UI updates.
                  if (response.data != null && response.data['data'] != null) {
                    final result = await ChatInterface.bulkSyncChats(
                      chatsData: [response.data['data'] as Map<String, dynamic>],
                    );
                    if (result.chats.isNotEmpty) {
                      ChatsSvc.updateChat(result.chats.first, override: true);
                    }
                  }
                  Navigator.of(context, rootNavigator: true).pop();
                  Navigator.of(context, rootNavigator: true).pop();
                } else {
                  Navigator.of(context, rootNavigator: true).pop();
                  showSnackbar("Error", "Failed to add ${participantController.text}!", type: SnackbarType.error);
                }
              },
            ),
          ],
          content: TextField(
            controller: participantController,
            decoration: const InputDecoration(
              labelText: "Phone Number / Email",
              border: OutlineInputBorder(),
            ),
            autofillHints: [AutofillHints.telephoneNumber, AutofillHints.email],
          ),
          title: Text("Add Participant", style: context.theme.textTheme.titleLarge),
          backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
        );
      });
}
