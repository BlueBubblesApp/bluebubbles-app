package flutter.plugins.contactsservice.contactsservice;

import android.annotation.TargetApi;
import android.database.Cursor;
import android.os.Build;

import static android.provider.ContactsContract.CommonDataKinds;
import static android.provider.ContactsContract.CommonDataKinds.StructuredPostal;

import java.util.HashMap;

@TargetApi(Build.VERSION_CODES.ECLAIR)
public class PostalAddress {

    public String label, street, city, postcode, region, country;

    public PostalAddress(String label, String street, String city, String postcode, String region, String country){
        this.label = label;
        this.street = street;
        this.city = city;
        this.postcode = postcode;
        this.region = region;
        this.country = country;
    }

    PostalAddress(Cursor cursor){
        this.label = getLabel(cursor);
        this.street = cursor.getString(cursor.getColumnIndex(StructuredPostal.STREET));
        this.city = cursor.getString(cursor.getColumnIndex(StructuredPostal.CITY));
        this.postcode = cursor.getString(cursor.getColumnIndex(StructuredPostal.POSTCODE));
        this.region = cursor.getString(cursor.getColumnIndex(StructuredPostal.REGION));
        this.country = cursor.getString(cursor.getColumnIndex(StructuredPostal.COUNTRY));
    }

    HashMap<String, String> toMap(){
        HashMap<String,String> result = new HashMap<>();
        result.put("label",label);
        result.put("street",street);
        result.put("city",city);
        result.put("postcode",postcode);
        result.put("region",region);
        result.put("country",country);
        return result;
    }

    public static PostalAddress fromMap(HashMap<String,String> map) {
        return new PostalAddress(map.get("label"), map.get("street"), map.get("city"), map.get("postcode"), map.get("region"), map.get("country"));
    }

    private String getLabel(Cursor cursor) {
        switch (cursor.getInt(cursor.getColumnIndex(StructuredPostal.TYPE))) {
            case StructuredPostal.TYPE_HOME:
                return "home";
            case StructuredPostal.TYPE_WORK:
                return "work";
            case StructuredPostal.TYPE_CUSTOM:
                final String label = cursor.getString(cursor.getColumnIndex(StructuredPostal.LABEL));
                return label != null ? label : "";
        }
        return "other";
    }

    public static int stringToPostalAddressType(String label) {
        if(label != null) {
            switch (label) {
                case "home": return CommonDataKinds.StructuredPostal.TYPE_HOME;
                case "work": return CommonDataKinds.StructuredPostal.TYPE_WORK;
                default: return CommonDataKinds.StructuredPostal.TYPE_OTHER;
            }
        }
        return StructuredPostal.TYPE_OTHER;
    }
}
