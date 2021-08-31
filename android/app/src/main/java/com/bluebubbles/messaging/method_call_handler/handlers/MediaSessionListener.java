package com.bluebubbles.messaging.method_call_handler.handlers;

import android.app.Activity;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.media.session.MediaController;
import android.media.MediaMetadata;
import android.media.session.PlaybackState;
import android.media.session.MediaSessionManager;
import android.media.session.MediaSessionManager.OnActiveSessionsChangedListener;
import android.os.Build;
import android.os.Looper;
import android.provider.Settings;
import android.util.Log;

import java.util.HashMap;
import java.util.List;
import java.io.ByteArrayOutputStream;

import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;
import androidx.appcompat.app.AlertDialog;
import androidx.palette.graphics.Palette;
import com.bluebubbles.messaging.services.CustomNotificationListenerService;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import static com.bluebubbles.messaging.MainActivity.engine;
import static com.bluebubbles.messaging.MainActivity.CHANNEL;


@RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
public class MediaSessionListener implements OnActiveSessionsChangedListener, Handler {

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;
    private List<MediaController> oldControllers;
    private MediaController.Callback callback;
    private MethodChannel backgroundChannel;

    public MediaSessionListener(Context context, MethodCall call, MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }


    @Override
    public void Handle() {
        backgroundChannel = new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL);
        MediaSessionManager manager = (MediaSessionManager) context.getSystemService(Context.MEDIA_SESSION_SERVICE);
        if (null == manager) {
            result.error("could_not_initialize", "Failed to initialize, manager == null", "");
        }
        callback = new MediaController.Callback() {
            @Override
            public void onMetadataChanged(MediaMetadata metadata) {
                String title = metadata.getString(MediaMetadata.METADATA_KEY_TITLE);
                if (title == null) {
                    title = "Unknown";
                }
                Bitmap icon = metadata.getBitmap(MediaMetadata.METADATA_KEY_ART);
                Bitmap icon2 = metadata.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART);
                Log.d("BlueBubblesApp", "Getting media metadata for media " + title);
                HashMap<String, Object> input = new HashMap<>();
                Palette p = null;
                if (icon != null) {
                    p = Palette.from(icon).generate();
                } else if (icon2 != null) {
                    p = Palette.from(icon2).generate();
                }
                if (p != null) {
                    int lightBg = p.getLightVibrantColor(Color.WHITE);
                    int darkBg = p.getDarkMutedColor(Color.BLACK);
                    int primary;
                    if (p.getVibrantColor(0xFF2196F3) != 0xFF2196F3) {
                        primary = p.getVibrantColor(0xFF2196F3);
                    } else if (p.getMutedColor(0xFF2196F3) != 0xFF2196F3) {
                        primary = p.getMutedColor(0xFF2196F3);
                    } else if (p.getLightMutedColor(0xFF2196F3) != 0xFF2196F3) {
                        primary = p.getLightMutedColor(0xFF2196F3);
                    } else {
                        primary = 0xFF2196F3;
                    }
                    Log.d("BlueBubblesApp", "Dominant color found (for debugging only): " + Integer.toString(p.getDominantColor(Color.BLACK)));
                    input.put("lightBg", lightBg);
                    input.put("darkBg", darkBg);
                    input.put("primary", primary);
                    Log.d("BlueBubblesApp", "Sending media metadata for media " + title);
                    backgroundChannel.invokeMethod("album-art", input);
                }
            }
        };
        List<MediaController> controllers = manager.getActiveSessions(new ComponentName(context, CustomNotificationListenerService.class));
        oldControllers = controllers;
        if (null != controllers && controllers.size() != 0) {
            for (MediaController controller : controllers) {
                controller.registerCallback(callback);
            }
        }
        manager.addOnActiveSessionsChangedListener(MediaSessionListener.this, new ComponentName(context, CustomNotificationListenerService.class));
        result.success("");
    }

    @Override
    public void onActiveSessionsChanged(@Nullable List<MediaController> controllers) {

        if (null == controllers || controllers.size() == 0) {
            return;
        }

        for (MediaController controller : oldControllers) {
            controller.unregisterCallback(callback);
        }
        oldControllers = controllers;
        for (MediaController controller : controllers) {
            controller.registerCallback(callback);
        }

    }

}