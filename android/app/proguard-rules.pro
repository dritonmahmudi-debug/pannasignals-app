-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep Firebase Messaging service entrypoints
-keep class com.google.firebase.messaging.FirebaseMessagingService { *; }
-keep class com.google.firebase.iid.FirebaseInstanceId { *; }

# Keep classes used by reflection (GSON, etc.)
-keep class com.google.gson.stream.** { *; }
-keep class com.google.gson.** { *; }

# OkHttp / Retrofit
-dontwarn okhttp3.**
-keep class okhttp3.** { *; }

# Keep Play Core (for deferred components and in-app updates)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Keep model classes used by serialization if needed (example):
# If you have model classes that are serialized/deserialized via reflection,
# add specific keep rules for them, e.g.:
# -keepclassmembers class com.yourpackage.models.** {
#   <fields>;
# }

# Keep Flutter embedding entrypoints (usually not necessary but safe)
-keep class io.flutter.app.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep Kotlin metadata
-keepclassmembers class kotlin.Metadata { *; }

# If you use Firebase Analytics / Crashlytics add their rules per docs
# (Crashlytics usually auto-applies with Gradle plugin)