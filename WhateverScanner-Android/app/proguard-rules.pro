# Keep ML Kit and Play Services model classes
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**

# Hilt generated components are handled by the Hilt Gradle plugin.

# Keep Kotlin metadata for reflection-based serialization helpers.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
