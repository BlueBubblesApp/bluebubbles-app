package com.bluebubbles.messaging.method_call_handler.handlers;

import android.app.Activity;
import android.content.Context;
import android.location.Location;
import android.util.Log;

import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.tasks.OnSuccessListener;

import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class GetLastLocation implements Handler{
    public static String TAG = "get-last-location";

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;
    private FusedLocationProviderClient fusedLocationClient;

    public GetLastLocation(Context context, MethodCall call, MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }

    @Override
    public void Handle() {
        // If we don't have the location client, let's get it
            fusedLocationClient = LocationServices.getFusedLocationProviderClient(context);

        // Fetch the last location
        fusedLocationClient.getLastLocation()
                .addOnSuccessListener((Activity) context, new OnSuccessListener<Location>() {
                    @Override
                    public void onSuccess(Location location) {
                        // Got last known location. In some rare situations this can be null.
                        if (location != null) {
                            // Logic to handle location object
                            Map<String, Double> latlng = new HashMap<String, Double>();
                            latlng.put("longitude", location.getLongitude());
                            latlng.put("latitude", location.getLatitude());
                            Log.d("Location", "Location retreived " + latlng.toString());
                            result.success(latlng);
                        } else {
                            Log.d("Location", "unable to retreive location");
                            result.success(null);
                        }
                    }
                });
    }
}
