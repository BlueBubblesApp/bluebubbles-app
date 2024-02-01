package com.bluebubbles.messaging.models

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

abstract class MethodCallHandlerImpl {
    abstract fun handleMethodCall(call: MethodCall, result: MethodChannel.Result, context: Context)
}