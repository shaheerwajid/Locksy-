# ============================================================================
# CRITICAL: Flutter Secure Storage - Required for encrypted storage in release
# ============================================================================
# Keep ALL FlutterSecureStorage classes and methods
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class io.flutter.plugins.fluttersecurestorage.** { *; }
-keepclassmembers class com.it_nomads.fluttersecurestorage.** { *; }
-keepclassmembers class io.flutter.plugins.fluttersecurestorage.** { *; }

# Keep FlutterSecureStorage ciphers (CRITICAL - often missed!)
-keep class com.it_nomads.fluttersecurestorage.ciphers.** { *; }
-keepclassmembers class com.it_nomads.fluttersecurestorage.ciphers.** { *; }

# ============================================================================
# CRITICAL: Android Keystore - Required for EncryptedSharedPreferences
# ============================================================================
-keep class android.security.keystore.** { *; }
-keep class java.security.KeyStore { *; }
-keep class java.security.KeyStore$* { *; }
-keepclassmembers class java.security.KeyStore { *; }
-keep class javax.crypto.** { *; }
-keepclassmembers class javax.crypto.** { *; }

# Keep AndroidX Security Crypto (used by EncryptedSharedPreferences)
-keep class androidx.security.crypto.** { *; }
-keepclassmembers class androidx.security.crypto.** { *; }
-keep class com.google.crypto.tink.** { *; }
-keepclassmembers class com.google.crypto.tink.** { *; }

# Keep EncryptedSharedPreferences implementation details
-keep class androidx.security.crypto.EncryptedSharedPreferences { *; }
-keep class androidx.security.crypto.EncryptedSharedPreferences$** { *; }
-keep class androidx.security.crypto.MasterKeys { *; }
-keep class androidx.security.crypto.MasterKeys$** { *; }
-keep class androidx.security.crypto.MasterKey { *; }
-keep class androidx.security.crypto.MasterKey$** { *; }
-keep class androidx.security.crypto.MasterKey$Builder { *; }

# ============================================================================
# CRITICAL: SharedPreferences - For onboarding flag persistence
# ============================================================================
-keep class android.content.SharedPreferences { *; }
-keep class android.content.SharedPreferences$Editor { *; }
-keepclassmembers class android.content.SharedPreferences { *; }
-keepclassmembers class android.content.SharedPreferences$Editor { *; }
-keep class android.app.SharedPreferencesImpl { *; }
-keep class android.app.SharedPreferencesImpl$EditorImpl { *; }
-keep class androidx.preference.** { *; }

# ============================================================================
# Firebase Messaging
# ============================================================================
-keep class com.google.firebase.messaging.** { *; }
-keep class io.flutter.plugins.firebase.messaging.** { *; }

# ============================================================================
# Prevent R8 from removing metadata needed for reflection
# ============================================================================
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes Exceptions

# ============================================================================
# Keep Flutter and Dart runtime
# ============================================================================
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class dart.** { *; }

# Keep path provider plugin
-keep class io.flutter.plugins.pathprovider.** { *; }

# Keep Gson (if used by any native Android code)
-keep class com.google.gson.** { *; }

# Keep WebRTC (for calls)
-keep class org.webrtc.** { *; }

# ============================================================================
# Prevent stripping of native methods
# ============================================================================
-keepclasseswithmembernames class * {
    native <methods>;
}

# ============================================================================
# Keep enum classes intact
# ============================================================================
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ============================================================================
# Keep Parcelables
# ============================================================================
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

