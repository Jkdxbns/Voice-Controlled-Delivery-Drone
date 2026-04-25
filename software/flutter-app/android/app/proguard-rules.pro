# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Google Play Core (for deferred components)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Preserve line number information for debugging stack traces
-keepattributes SourceFile,LineNumberTable

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep all classes referenced by Flutter
-dontwarn io.flutter.embedding.**
