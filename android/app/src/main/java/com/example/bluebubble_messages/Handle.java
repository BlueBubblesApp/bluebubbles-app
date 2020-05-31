package com.example.bluebubble_messages;


import android.annotation.SuppressLint;
import android.content.ContentValues;
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

    public static Handle fromMap(Map<String, Object> json) {
        Log.d("db", "creating from map " + json.containsKey("address"));
        Handle handle = new Handle();
        handle.id = json.containsKey("ROWID") ? (int) json.get("ROWID") : null;
        handle.address = (String) json.get("address");
        handle.country = json.containsKey("country") ? (String) json.get("country") : null;
        handle.uncanonicalizedId = json.containsKey("uncanonicalizedId")
                ? (String) json.get("uncanonicalizedId")
                : null;
        return handle;

    }
    @SuppressLint("NewApi")
    public Handle save(SQLiteDatabase db, boolean updateIfAbsent) {
        // Try to find an existing chat before saving it
//        Handle existing = Handle.findOne({"address": this.address});
        Cursor existing = null;
        if(this.address != null) {
            existing = db.rawQuery("SELECT * FROM handle WHERE address = ? LIMIT 1", new String[]{this.address});
            if (existing.moveToFirst() ) {
                this.id = existing.getInt(existing.getColumnIndex("ROWID"));
            }
        }

        // If it already exists, update it
        if (existing == null) {
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


