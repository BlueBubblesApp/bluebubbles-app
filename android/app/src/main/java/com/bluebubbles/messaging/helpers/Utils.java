package com.bluebubbles.messaging;

import java.sql.Timestamp;
import java.util.Map;

class Utils {
    public static Object parseField(Map<String, Object> json, String field, String intendedType) {
        // Handle cases where we want to return null
        if (!json.containsKey(field) || json.get(field) == null) {
            if (intendedType.equals("boolean")) return false;  // If null, let's assume false
            return null;
        }

        String stringVal = String.valueOf(json.get(field));
        if (stringVal.equals("null")) {
            if (intendedType.equals("boolean")) return false;  // If null, let's assume false
            return null;
        }

        switch (intendedType) {
            case "integer":
                return Integer.valueOf(stringVal);
            case "long":
                return Long.valueOf(stringVal);
            case "boolean":
                return Boolean.valueOf(stringVal);
            case "timestamp":
                return new Timestamp(Long.valueOf(stringVal));
            default:
                return stringVal;
        }
    }
}