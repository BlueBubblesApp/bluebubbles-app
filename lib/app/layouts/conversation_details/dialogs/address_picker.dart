import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/global/contact_address.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

void launchIntent(bool video, String address) async {
  if (address.contains("@")) {
    launchUrl(Uri(scheme: "mailto", path: address));
  } else if (await Permission.phone.request().isGranted) {
    if (video) {
      await mcs.invokeMethod("google-duo", {"number": address});
    } else {
      launchUrl(Uri(scheme: "tel", path: address));
    }
  }
}

void showAddressPicker(Contact? contact, Handle handle, BuildContext context, {bool isEmail = false, bool video = false, bool isLongPressed = false}) async {
  if (contact == null) {
    launchIntent(video, handle.address);
  } else {
    List<ContactAddress> items = isEmail ? getUniqueEmails(contact.emailAddresses) : getUniqueNumbers(contact.phoneNumbers);
    if (items.length == 1) {
      launchIntent(video, items.first.address);
    } else if (!isEmail && handle.defaultPhone != null && !isLongPressed) {
      launchIntent(video, handle.defaultPhone!);
    } else if (isEmail && handle.defaultEmail != null && !isLongPressed) {
      launchIntent(video, handle.defaultEmail!);
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
                      items[i].address,
                      style: context.theme.textTheme.bodyLarge,
                      textAlign: TextAlign.start,
                    ),
                    onPressed: () {
                      if (data.value) {
                        if (isEmail) {
                          handle.defaultEmail = items[i].address;
                          handle.updateDefaultEmail(items[i].address);
                        } else {
                          handle.defaultPhone = items[i].address;
                          handle.updateDefaultPhone(items[i].address);
                        }
                      }
                      launchIntent(video, items[i].address);
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