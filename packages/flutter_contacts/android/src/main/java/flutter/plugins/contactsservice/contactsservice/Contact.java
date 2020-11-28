package flutter.plugins.contactsservice.contactsservice;

import java.util.ArrayList;
import java.util.HashMap;

public class Contact implements Comparable<Contact> {

    Contact(String id) {
        this.identifier = id;
    }

    private Contact() {
    }

    String identifier;
    String displayName, givenName, middleName, familyName, prefix, suffix, company, jobTitle, note, birthday, androidAccountType, androidAccountName;
    ArrayList<Item> emails = new ArrayList<>();
    ArrayList<Item> phones = new ArrayList<>();
    ArrayList<PostalAddress> postalAddresses = new ArrayList<>();
    byte[] avatar = new byte[0];

    HashMap<String, Object> toMap() {
        HashMap<String, Object> contactMap = new HashMap<>();
        contactMap.put("identifier", identifier);
        contactMap.put("displayName", displayName);
        contactMap.put("givenName", givenName);
        contactMap.put("middleName", middleName);
        contactMap.put("familyName", familyName);
        contactMap.put("prefix", prefix);
        contactMap.put("suffix", suffix);
        contactMap.put("company", company);
        contactMap.put("jobTitle", jobTitle);
        contactMap.put("avatar", avatar);
        contactMap.put("note", note);
        contactMap.put("birthday", birthday);
        contactMap.put("androidAccountType", androidAccountType);
        contactMap.put("androidAccountName", androidAccountName);

        ArrayList<HashMap<String, String>> emailsMap = new ArrayList<>();
        for (Item email : emails) {
            emailsMap.add(email.toMap());
        }
        contactMap.put("emails", emailsMap);

        ArrayList<HashMap<String, String>> phonesMap = new ArrayList<>();
        for (Item phone : phones) {
            phonesMap.add(phone.toMap());
        }
        contactMap.put("phones", phonesMap);

        ArrayList<HashMap<String, String>> addressesMap = new ArrayList<>();
        for (PostalAddress address : postalAddresses) {
            addressesMap.add(address.toMap());
        }
        contactMap.put("postalAddresses", addressesMap);

        return contactMap;
    }

    @SuppressWarnings("unchecked")
    static Contact fromMap(HashMap map) {
        Contact contact = new Contact();
        contact.identifier = (String) map.get("identifier");
        contact.givenName = (String) map.get("givenName");
        contact.middleName = (String) map.get("middleName");
        contact.familyName = (String) map.get("familyName");
        contact.prefix = (String) map.get("prefix");
        contact.suffix = (String) map.get("suffix");
        contact.company = (String) map.get("company");
        contact.jobTitle = (String) map.get("jobTitle");
        contact.avatar = (byte[]) map.get("avatar");
        contact.note = (String) map.get("note");
        contact.birthday = (String) map.get("birthday");
        contact.androidAccountType = (String) map.get("androidAccountType");
        contact.androidAccountName = (String) map.get("androidAccountName");

        ArrayList<HashMap> emails = (ArrayList<HashMap>) map.get("emails");
        if (emails != null) {
            for (HashMap email : emails) {
                contact.emails.add(Item.fromMap(email));
            }
        }
        ArrayList<HashMap> phones = (ArrayList<HashMap>) map.get("phones");
        if (phones != null) {
            for (HashMap phone : phones) {
                contact.phones.add(Item.fromMap(phone));
            }
        }
        ArrayList<HashMap> postalAddresses = (ArrayList<HashMap>) map.get("postalAddresses");
        if (postalAddresses != null) {
            for (HashMap postalAddress : postalAddresses) {
                contact.postalAddresses.add(PostalAddress.fromMap(postalAddress));
            }
        }
        return contact;
    }

    @Override
    public int compareTo(Contact contact) {
        String givenName1 = this.givenName == null ? "" : this.givenName.toLowerCase();
        String givenName2 = contact == null ? ""
            : (contact.givenName == null ? "" : contact.givenName.toLowerCase());
        return givenName1.compareTo(givenName2);
    }
}