# R8 keep/dontwarn rules for release (minifyEnabled + shrinkResources).
# AGP already merges in the default proguard-android-optimize.txt and every
# dependency's bundled consumer-rules.pro — this file only covers cases R8
# can't infer on its own (reflection, JSON model fields, optional TLS
# providers referenced but not on the classpath, etc).

# ---- Flutter engine / plugins -----------------------------------------
# Flutter's official guidance for enabling R8: keep the engine + generated
# plugin registrant so plugin classes invoked through the embedding aren't
# stripped or renamed.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# The engine's deferred-components support references the Play Core split
# install/compat APIs even though this app doesn't ship the play-core
# dependency (no dynamic feature modules). Without this, R8 fails the build
# with "Missing classes detected while running R8".
-dontwarn com.google.android.play.core.**

# ---- Gson (JSON models for the native HTTP/socket layer) --------------
# Gson 2.10.x does not bundle consumer proguard rules; without keeping
# Signature/annotations and the model fields, R8 will happily rename/strip
# @SerializedName-annotated fields that are only ever touched by reflection.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-dontwarn sun.misc.**
-keep class com.google.gson.reflect.TypeToken
-keep class * extends com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

-keep class com.bluebubbles.messaging.services.network.** {
    <fields>;
    <init>(...);
}

# ---- Retrofit / OkHttp --------------------------------------------------
# Retrofit and OkHttp both ship consumer-rules.pro, but their optional
# TLS-provider integrations (only used when those artifacts are present on
# the classpath, which they aren't here) still trip R8's default "missing
# classes are an error" behavior.
-dontwarn okhttp3.internal.platform.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
-dontwarn javax.annotation.**
-keepattributes Exceptions

-keep interface com.bluebubbles.messaging.services.network.BlueBubblesApi { *; }

# ---- Firebase (Cloud Messaging / Firestore / Realtime Database) --------
# firebase-firestore pulls in gRPC, which references optional Netty/Conscrypt
# transports that aren't bundled here.
-dontwarn io.grpc.netty.**
-dontwarn io.netty.**

# ---- WorkManager (DartWorker background execution) ---------------------
# WorkManager instantiates workers by reflection using the class name stored
# in its own DB, so the (Context, WorkerParameters) constructor must survive
# even though nothing in app code calls it directly.
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}

# ---- UnifiedPush connector ----------------------------------------------
# Small library; play it safe in case it doesn't ship its own consumer rules.
-keep class org.unifiedpush.android.connector.** { *; }
