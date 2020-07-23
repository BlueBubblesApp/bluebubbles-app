package com.bricktheworld.giftextfield;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/** GiftextfieldPlugin */
public class GiftextfieldPlugin implements FlutterPlugin {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity

  public static void registerWith(Registrar registrar) {
//    final MethodChannel channel = new MethodChannel(registrar.messenger(), "giftextfield");
//    channel.setMethodCallHandler(new EditTextFactory());
      registrar.platformViewRegistry().registerViewFactory("giftextfield", new EditTextFactory(registrar.messenger()));
  }

    @Override
    public void onAttachedToEngine(FlutterPluginBinding flutterPluginBinding) {
        flutterPluginBinding.getPlatformViewRegistry().registerViewFactory("giftextfield", new EditTextFactory(flutterPluginBinding.getBinaryMessenger()));
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding flutterPluginBinding) {
    }
}
