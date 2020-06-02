package com.example.bluebubble_messages;
;
import android.annotation.SuppressLint;
import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.os.Build;
import android.util.Log;

import androidx.annotation.RequiresApi;

import org.json.JSONObject;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

class Handle {
    Integer id;
    String address;
    String country;
    String uncanonicalizedId;

    private SQLiteDatabase db;

    public Handle(Context context) {
        DatabaseHelper helper = DatabaseHelper.getInstance(context);
        this.db = helper.getWritableDatabase();
    }

    public static Handle fromMap(Map<String, Object> json, Context context) {
        Handle handle = new Handle(context);

        // Parse generic fields
        handle.id = (Integer) Utils.parseField(json, "ROWID", "integer");
        handle.address = (String) Utils.parseField(json, "address", "string");
        handle.country = (String) Utils.parseField(json, "country", "string");
        handle.uncanonicalizedId = (String) Utils.parseField(json, "uncanonicalizedId", "string");

        return handle;

    }
    @SuppressLint("NewApi")
    public Handle save(boolean updateIfAbsent) {
        Cursor cursor = null;
        if(this.address != null) {
            cursor = db.rawQuery("SELECT * FROM handle WHERE address = ? LIMIT 1", new String[]{this.address});
            if (cursor.moveToFirst() ) {
                this.id = cursor.getInt(cursor.getColumnIndex("ROWID"));
            }
        }

        int count = cursor.getCount();
        cursor.close();

        // If it already exists, update it
        if (count == 0) {
            // Remove the ID from the map for inserting
            ContentValues map = this.toContentValues();
            map.remove("ROWID");
            try {
                this.id = (int) db.insert("handle", null, map);
                if(this.id == -1) {
                    this.id = null;
                }
            } catch (Exception e) {
                this.id = null;
            }
        }

        return this;
    }



    public Map<String, Object> toMap() {
        Map<String, Object> map = new HashMap<String, Object>();
        map.put("ROWID", id);
        map.put("address", address);
        map.put("country", country);
        map.put("uncanonicalizedId", uncanonicalizedId);
        return map;
    }

    public ContentValues toContentValues() {
        ContentValues map = new ContentValues() ;
        map.put("ROWID", id);
        map.put("address", address);
        map.put("country", country);
        map.put("uncanonicalizedId", uncanonicalizedId);
        return map;
    }

    ;
}


