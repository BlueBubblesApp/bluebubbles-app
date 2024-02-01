package com.bluebubbles.messaging.services.firebase

import android.content.Context
import android.util.Log
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import com.google.firebase.FirebaseApp
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Set the next-restart value in the Firebase database
class UpdateNextRestartHandler: MethodCallHandlerImpl() {
    companion object {
        const val tag: String = "set-next-restart"
    }
    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        // Make sure the FirebaseApp is initialized
        lateinit var firebaseApp: FirebaseApp
        try {
            firebaseApp = FirebaseApp.getInstance()
        } catch (e: Exception) {
            result.error("500", "No Firebase app found!", e)
            return
        }

        val nextRestart: Long = call.argument("value")!!
        Log.d(Constants.logTag, "Updating next restart value...")
        // null databaseUrl indicates Cloud Firestore setup
        if (firebaseApp.options.databaseUrl == null) {
            val newData = hashMapOf("nextRestart" to nextRestart)
            FirebaseFirestore.getInstance().collection("server").document("config").set(newData, SetOptions.merge())
        } else {
            FirebaseDatabase.getInstance().getReference("config").child("nextRestart").setValue(nextRestart)
        }
        result.success(null)
    }
}