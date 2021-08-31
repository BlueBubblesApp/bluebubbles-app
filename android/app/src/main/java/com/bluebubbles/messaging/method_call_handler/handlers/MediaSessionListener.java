package com.bluebubbles.messaging.method_call_handler.handlers;

import android.app.Activity;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
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
                String title = metadata.getString(MediaMetadata.METADATA_KEY_ARTIST);
                Bitmap icon = metadata.getBitmap(MediaMetadata.METADATA_KEY_ART);
                Bitmap icon2 = metadata.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART);
                Log.d("test", title);
                if (icon != null) {
                    Palette p = Palette.from(icon).generate();
                    Palette.Swatch vibrant = p.getVibrantSwatch();
                    if (vibrant != null) {
                        int color = vibrant.getRgb();
                        HashMap<String, Object> input = new HashMap<>();
                        input.put("data", color);
                        backgroundChannel.invokeMethod("album-art", input);
                    } else {
                        backgroundChannel.invokeMethod("album-art", null);
                    }
                } else if (icon2 != null) {
                    Palette p = Palette.from(icon2).generate();
                    Palette.Swatch vibrant = p.getVibrantSwatch();
                    if (vibrant != null) {
                        int color = vibrant.getRgb();
                        HashMap<String, Object> input = new HashMap<>();
                        input.put("data", color);
                        backgroundChannel.invokeMethod("album-art", input);
                    } else {
                        backgroundChannel.invokeMethod("album-art", null);
                    }
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