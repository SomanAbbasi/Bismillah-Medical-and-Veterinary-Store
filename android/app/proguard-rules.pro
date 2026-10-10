# Flutter Local Notifications & Gson R8/ProGuard configuration
# Preserves generic signatures required by Gson TypeToken deserialization
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Preserve Gson classes and TypeToken
-dontwarn com.google.gson.**
-keep class com.google.gson.** { *; }
-keep interface com.google.gson.** { *; }

# Preserve flutter_local_notifications plugin classes and models
-dontwarn com.dexterous.flutterlocalnotifications.**
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
