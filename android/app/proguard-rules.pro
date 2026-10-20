# Flutter ProGuard / R8 Rules for ArvaLink Release Build

# Flutter Engine & Embedding
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# Preserve Flutter annotations, signatures, and reflection attributes
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Flutter Plugins & Secure Storage
-keep class io.flutter.plugins.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class androidx.security.crypto.** { *; }

# Suppress known harmless warnings
-dontwarn io.flutter.embedding.**
-dontwarn androidx.security.crypto.**
