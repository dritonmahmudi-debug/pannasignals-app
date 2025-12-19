# Optional: android/app/proguard-rules.pro
# If you enable code shrinking / obfuscation, ensure Firebase classes are kept.
# Path: android/app/proguard-rules.pro

-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }