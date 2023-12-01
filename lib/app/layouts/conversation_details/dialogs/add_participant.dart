import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/string_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slugify/slugify.dart';
import 'package:tuple/tuple.dart';

void showAddParticipant(BuildContext context, Chat chat) {
  final TextEditingController participantController = TextEditingController();
  showDialog(
    context: context,
    builder: (_) {
      return AlertDialog(
        actions: [
          TextButton(
            child: Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
            onPressed: () => Get.back(),
          ),
          TextButton(
            child: Text("Pick Contact", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
            onPressed: () async {
              final contacts = <Tuple2<String, String>>[];
              final cache = [];
              String slugText(String text) {
                return slugify(text, delimiter: '').toString().replaceAll('-', '');
              }

              for (Contact contact in cs.contacts) {
                for (String phone in contact.phones) {
                  String cleansed = slugText(phone);

                  if (!cache.contains(cleansed)) {
                    cache.add(cleansed);
                    contacts.add(Tuple2(phone, contact.displayName));
                  }
                }

                for (String email in contact.emails) {
                  String emailVal = slugText.call(email);

                  if (!cache.contains(emailVal)) {
                    cache.add(emailVal);
                    contacts.add(Tuple2(email, contact.displayName));
                  }
                }
              }
              contacts.sort((c1, c2) => c1.item2.compareTo(c2.item2));
              Tuple2<String, String>? selected;
              await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text("Pick Contact", style: context.theme.textTheme.titleLarge),
                    backgroundColor: context.theme.colorScheme.properSurface,
                    content: SingleChildScrollView(
                      child: Container(
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
                                itemBuilder: (context, index) {
                                  return ListTile(
                                    mouseCursor: MouseCursor.defer,
                                    title: Text(contacts[index].item2),
                                    subtitle: Text(contacts[index].item1),
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
                  )
              );
              if (selected?.item1 != null) {
                if (!selected!.item1.isEmail) {
                  participantController.text = cleansePhoneNumber(selected!.item1);
                } else {
                  participantController.text = selected!.item1;
                }
              }
            },
          ),
          TextButton(
            child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
            onPressed: () async {
              if (participantController.text.isEmpty
                  || (!participantController.text.isEmail && !participantController.text.isPhoneNumber)) {
                showSnackbar("Error", "Enter a valid address!");
                return;
              }
              showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      backgroundColor: context.theme.colorScheme.properSurface,
                      title: Text(
                        "Adding ${participantController.text}...",
                        style: context.theme.textTheme.titleLarge,
                      ),
                      content: Container(
                        height: 70,
                        child: Center(
                          child: CircularProgressIndicator(
                            backgroundColor: context.theme.colorScheme.properSurface,
                            valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                          ),
                        ),
                      ),
                    );
                  }
              );
              final response = await http.chatParticipant("add", chat.guid, participantController.text);
              if (response.statusCode == 200) {
                Get.back();
                Get.back();
                showSnackbar("Notice", "Added ${participantController.text} successfully!");
              } else {
                Get.back();
                showSnackbar("Error", "Failed to add ${participantController.text}!");
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
        backgroundColor: context.theme.colorScheme.properSurface,
      );
    }
  );
}