package flutter.plugins.contactsservice.contactsservice;

import android.database.Cursor;
import android.provider.ContactsContract;
import static android.provider.ContactsContract.CommonDataKinds;

import java.util.HashMap;

/***
 * Represents an object which has a label and a value
 * such as an email or a phone
 ***/
public class Item{

    public String label, value;

    public Item(String label, String value) {
        this.label = label;
        this.value = value;
    }

    HashMap<String, String> toMap(){
        HashMap<String,String> result = new HashMap<>();
        result.put("label",label);
        result.put("value",value);
        return result;
    }

    public static Item fromMap(HashMap<String,String> map){
        return new Item(map.get("label"), map.get("value"));
    }

    public static String getPhoneLabel(int type, Cursor cursor){
        switch (type) {
            case CommonDataKinds.Phone.TYPE_HOME:
                return "home";
            case CommonDataKinds.Phone.TYPE_WORK:
                return "work";
            case CommonDataKinds.Phone.TYPE_MOBILE:
                return "mobile";
            case CommonDataKinds.Phone.TYPE_FAX_WORK:
                return "fax work";
            case CommonDataKinds.Phone.TYPE_FAX_HOME:
                return "fax home";
            case CommonDataKinds.Phone.TYPE_MAIN:
                return "main";
            case CommonDataKinds.Phone.TYPE_COMPANY_MAIN:
                return "company";
            case CommonDataKinds.Phone.TYPE_PAGER:
                return "pager";
            case CommonDataKinds.Phone.TYPE_CUSTOM:
                if (cursor.getString(cursor.getColumnIndex(CommonDataKinds.Phone.LABEL)) != null) {
                    return cursor.getString(cursor.getColumnIndex(CommonDataKinds.Phone.LABEL)).toLowerCase();
                } else return "";
            default:
                return "other";
        }
    }

    public static String getEmailLabel(int type, Cursor cursor) {
        switch (type) {
            case CommonDataKinds.Email.TYPE_HOME:
                return "home";
            case CommonDataKinds.Email.TYPE_WORK:
                return "work";
            case CommonDataKinds.Email.TYPE_MOBILE:
                return "mobile";
            case CommonDataKinds.Email.TYPE_CUSTOM:
                if (cursor.getString(cursor.getColumnIndex(CommonDataKinds.Email.LABEL)) != null) {
                    return cursor.getString(cursor.getColumnIndex(CommonDataKinds.Email.LABEL)).toLowerCase();
                } else return "";
            default:
                return "other";
        }
    }

    public static int stringToPhoneType(String label) {
        if (label != null) {
            switch (label) {
                case "home":
                    return CommonDataKinds.Phone.TYPE_HOME;
                case "work":
                    return CommonDataKinds.Phone.TYPE_WORK;
                case "mobile":
                    return CommonDataKinds.Phone.TYPE_MOBILE;
                case "fax work":
                    return CommonDataKinds.Phone.TYPE_FAX_WORK;
                case "fax home":
                    return CommonDataKinds.Phone.TYPE_FAX_HOME;
                case "main":
                    return CommonDataKinds.Phone.TYPE_MAIN;
                case "company":
                    return CommonDataKinds.Phone.TYPE_COMPANY_MAIN;
                case "pager":
                    return CommonDataKinds.Phone.TYPE_PAGER;
                case "other":
                    return CommonDataKinds.Phone.TYPE_OTHER;
                default:
                    return CommonDataKinds.Phone.TYPE_CUSTOM;
            }
        }
        return CommonDataKinds.Phone.TYPE_OTHER;
    }

    public static int stringToEmailType(String label) {
        if (label != null) {
            switch (label) {
                case "home":
                    return CommonDataKinds.Email.TYPE_HOME;
                case "work":
                    return CommonDataKinds.Email.TYPE_WORK;
                case "mobile":
                    return CommonDataKinds.Email.TYPE_MOBILE;
                default:
                    return CommonDataKinds.Email.TYPE_OTHER;
            }
        }
        return CommonDataKinds.Email.TYPE_OTHER;
    }

}