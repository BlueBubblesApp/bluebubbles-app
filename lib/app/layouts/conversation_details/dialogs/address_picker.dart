import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

void launchIntent(String address) async {
  if (address.contains("@")) {
    launchUrl(Uri(scheme: "mailto", path: address));
  } else if (await Permission.phone.request().isGranted) {
    launchUrl(Uri(scheme: "tel", path: address));
  }
}

void showAddressPicker(Contact? contact, Handle handle, BuildContext context, {bool isEmail = false, bool isLongPressed = false}) async {
  if (contact == null) {
    launchIntent(handle.address);
  } else {
    List<String> items = isEmail ? getUniqueEmails(contact.emails) : getUniqueNumbers(contact.phones);
    if (items.length == 1) {
      launchIntent(items.first);
    } else if (!isEmail && handle.defaultPhone != null && !isLongPressed) {
      launchIntent(handle.defaultPhone!);
    } else if (isEmail && handle.defaultEmail != null && !isLongPressed) {
      launchIntent(handle.defaultEmail!);
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: context.theme.colorScheme.properSurface,
            title:
            Text("Select Address", style: context.theme.textTheme.titleLarge),
            content: ObxValue<Rx<bool>>((data) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < items.length; i++)
                  TextButton(
                    child: Text(
                      items[i],
                      style: context.theme.textTheme.bodyLarge,
                      textAlign: TextAlign.start,
                    ),
                    onPressed: () {
                      if (data.value) {
                        if (isEmail) {
                          handle.defaultEmail = items[i];
                          handle.updateDefaultEmail(items[i]);
                        } else {
                          handle.defaultPhone = items[i];
                          handle.updateDefaultPhone(items[i]);
                        }
                      }
                      launchIntent(items[i]);
                      Navigator.of(context).pop();
                    },
                  ),
                Row(
                  children: <Widget>[
                    SizedBox(
                      height: 48.0,
                      width: 24.0,
                      child: Checkbox(
                        value: data.value,
                        activeColor: context.theme.colorScheme.primary,
                        onChanged: (bool? value) {
                          data.value = value!;
                        },
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        padding: const EdgeInsets.only(left: 5),
                        elevation: 0.0
                      ),
                      onPressed: () {
                        data = data.toggle();
                      },
                      child: Text(
                        "Remember my selection", style: context.theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                Text(
                  "Long press the ${isEmail ? "email" : "call"} button to reset your default selection",
                  style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface),
                ),
              ],
            ),
            false.obs,
          ));
        },
      );
    }
  }
}