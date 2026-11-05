pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // API 37'yi destekleyen ilk AGP 9.1.1 (developer.android.com, "Minimum
    // versions of tools for Android API level": 37.0 → AGP 9.1.1). API 36'dan
    // beri SDK platformları küçük sürümlü yayımlanıyor; depoda
    // `platforms;android-37` yok, `android-37.0` var. 9.1.0 `compileSdk = 37`
    // için `android-37` hedefini arıyor ve temiz SDK'da "Failed to find target
    // with hash string 'android-37'" ile düşüyordu; 9.1.1 aynı değeri
    // `android-37.0` ile eşliyor. Bu sürüm bütün modüllere uygulanır, yani
    // `compileSdk = 37` yazan eklentiler (permission_handler_android 14) de
    // aynı yoldan derlenir.
    id("com.android.application") version "9.1.1" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
    id("com.google.gms.google-services") version "4.5.0" apply false
}

include(":app")
