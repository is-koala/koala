import java.util.Properties

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

val signingProperties = Properties()
val signingPropertiesFile = rootProject.file("key.properties")
if (signingPropertiesFile.exists()) {
    signingPropertiesFile.inputStream().use { signingProperties.load(it) }
}

fun signingValue(propertyName: String, environmentName: String): String? =
    System.getenv(environmentName)?.takeIf { it.isNotBlank() }
        ?: signingProperties.getProperty(propertyName)?.takeIf { it.isNotBlank() }

val releaseStorePath = signingValue("storeFile", "KOALA_ANDROID_KEYSTORE_PATH")
val releaseStorePassword = signingValue("storePassword", "KOALA_ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "KOALA_ANDROID_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "KOALA_ANDROID_KEY_PASSWORD")
val hasReleaseSigning = listOf(
    releaseStorePath,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { it != null }

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

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStorePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
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
                "mapsApiKey" to (
                    System.getenv("KOALA_ANDROID_MAPS_API_KEY_STAGING")
                        ?: localProperties.getProperty("MAPS_API_KEY_STAGING")
                        ?: ""
                ),
            )
        }
        create("production") {
            dimension = "environment"
            manifestPlaceholders += mapOf(
                "appLabel" to "Koala",
                "appUrlScheme" to "koala",
                "usesCleartextTraffic" to "false",
                "mapsApiKey" to (
                    System.getenv("KOALA_ANDROID_MAPS_API_KEY_PRODUCTION")
                        ?: localProperties.getProperty("MAPS_API_KEY_PRODUCTION")
                        ?: ""
                ),
            )
        }
    }

    buildTypes {
        release {
            // Release hiçbir zaman debug anahtarıyla imzalanmaz. Yerelde
            // key.properties, CI'da yalnız secret-backed ortam değişkenleri
            // kullanılır; değerler eksikse çıktı imzasız kalır ve release
            // workflow'u yüklemeden önce açıkça durur.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                null
            }
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
