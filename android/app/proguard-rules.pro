# Release shrinking rules beyond Flutter's own.

# flutter_local_notifications stores scheduled reminders with Gson, which
# reads generic type data that R8 strips by default ("Missing type
# parameter" when a reminder is scheduled in a release build).
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
-keep class com.dexterous.flutterlocalnotifications.** { *; }
