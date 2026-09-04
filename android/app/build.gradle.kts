import java.util.Properties

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

plugins {
    id("com.android.application")
    // Kotlin derlemesi AGP'nin built-in Kotlin'i üzerinden yürüyor; ayrı bir
    // kotlin-android eklentisi uygulanmıyor (android.builtInKotlin=true).
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.koala"
    // permission_handler_android 14 compileSdk 37 ile derleniyor; Flutter'ın
    // varsayılanı (flutter.compileSdkVersion) hâlâ 36 olduğu için elle sabitlendi.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.iskoala.koala"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            manifestPlaceholders += mapOf(
                "appLabel" to "Koala Dev",
                "appUrlScheme" to "koala-dev",
                "usesCleartextTraffic" to "true",
                "mapsApiKey" to (localProperties.getProperty("MAPS_API_KEY_DEV") ?: ""),
            )
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            manifestPlaceholders += mapOf(
                "appLabel" to "Koala Staging",
                "appUrlScheme" to "koala-staging",
                "usesCleartextTraffic" to "false",
                "mapsApiKey" to (localProperties.getProperty("MAPS_API_KEY_STAGING") ?: ""),
            )
        }
        create("production") {
            dimension = "environment"
            manifestPlaceholders += mapOf(
                "appLabel" to "Koala",
                "appUrlScheme" to "koala",
                "usesCleartextTraffic" to "false",
                "mapsApiKey" to (localProperties.getProperty("MAPS_API_KEY_PRODUCTION") ?: ""),
            )
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
