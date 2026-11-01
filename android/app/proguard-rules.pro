# Aturan untuk melindungi Mobile Scanner dan CameraX pada mode Release
-keep class com.google.zxing.** { *; }
-keep class com.journeyapps.barcodescanner.** { *; }
-keep class androidx.camera.** { *; }
-dontwarn com.google.zxing.**
-dontwarn androidx.camera.**