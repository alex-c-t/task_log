# Flutter Local Notifications Proguard Rules
# Preserves the plugin and its internal data structures needed for JSON serialization/deserialization

-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep enum com.dexterous.flutterlocalnotifications.** { *; }

# Preserve generic type information (Crucial for "Missing type parameter" error)
-keepattributes Signature, EnclosingMethod, InnerClasses

# Preserve Gson (used internally by the plugin)
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class com.google.gson.internal.bind.ReflectiveTypeAdapterFactory { *; }
-keep class * extends com.google.gson.TypeAdapter

# Preserve Android built-ins used for notifications
-keep class android.app.Notification { *; }
-keep class android.app.PendingIntent { *; }
