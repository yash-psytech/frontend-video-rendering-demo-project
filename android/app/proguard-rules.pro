# Flutter video_player plugin - prevent Pigeon classes from being stripped
-keep class dev.flutter.pigeon.** { *; }
-keep class dev.flutter.pigeon.video_player_android.** { *; }
-keep class io.flutter.plugins.videoplayer.** { *; }
-keepattributes Signature, InnerClasses, EnclosingMethod

# Keep Flutter embedding
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# FFmpeg Kit
-keep class com.arthenica.ffmpegkit.** { *; }
-keep class com.arthenica.mobileffmpeg.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelables
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# Google Play Core (deferred components) - mark as missing OK
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
