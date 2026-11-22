import groovy.json.JsonSlurper
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
    // Kotlin AGP 9'un built-in Kotlin'inden geliyor; `kotlin-android`
    // uygulanmıyor. Flutter eklentisi Android eklentisinden sonra gelmeli.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// App Links host'ları config/<flavor>.json'daki WEB_HOSTS'tan geliyor.
// Manifestteki host satırı sayısı tutmazsa derleme eksik host'la çıkmak yerine
// burada durur (#155).
fun appLinkPlaceholders(flavor: String, manifestHostLines: Int): Map<String, String> {
    val configFile = rootProject.file("../config/$flavor.json")
    check(configFile.exists()) { "config/$flavor.json bulunamadı; App Links host'u okunamıyor." }
    val config = JsonSlurper().parse(configFile) as Map<*, *>
    val hosts = (config["WEB_HOSTS"] as? String).orEmpty()
        .split(',')
        .map { it.trim() }
        .filter { it.isNotEmpty() }
    check(hosts.size == manifestHostLines) {
        "config/$flavor.json WEB_HOSTS ${hosts.size} host taşıyor, " +
            "android/app/src/$flavor/AndroidManifest.xml $manifestHostLines host satırı bekliyor: $hosts"
    }
    return buildMap {
        put("appLinkHost", hosts[0])
        if (hosts.size > 1) put("appLinkHostAlias", hosts[1])
    }
}

configurations.configureEach {
    resolutionStrategy.dependencySubstitution {
        // Latin OCR modelini Play Services varyantına çevirmek production
        // APK'sından ~31 MB düşürüyor. Eklenti yeni bir gömülü sürüme geçerse
        // aşağıdaki doğrulama açıkça hata vermeli.
        substitute(module("com.google.mlkit:text-recognition:16.0.1"))
            .using(module("com.google.android.gms:play-services-mlkit-text-recognition:19.0.1"))
            .because("Latin OCR modeli Google Play Services üzerinden indirilir")
    }
}

val verifyUnbundledMlKitModels by tasks.registering {
    group = "verification"
    description = "Production runtime graph uses only the unbundled ML Kit models (Latin OCR, barcode)"

    doLast {
        val runtime = configurations.getByName("productionReleaseRuntimeClasspath")
        val modules = runtime.incoming.resolutionResult.allComponents
            .mapNotNull { it.moduleVersion }

        val bundled = modules.filter {
            it.group == "com.google.mlkit" && it.name == "text-recognition"
        }
        check(bundled.isEmpty()) {
            "Bundled ML Kit text-recognition production graph'a geri döndü: $bundled"
        }

        val unbundled = modules.filter {
            it.group == "com.google.android.gms" &&
                it.name == "play-services-mlkit-text-recognition"
        }
        check(unbundled.size == 1 && unbundled.single().version == "19.0.1") {
            "Production graph exact unbundled ML Kit 19.0.1 bekliyor: $unbundled"
        }

        // Biniş QR'ı (#217): barkod modeli `useUnbundled=true` ile Play
        // Services'tan geliyor. Bayrak düşerse eklenti sessizce gömülü modele
        // döner; burada kırılsın.
        val bundledBarcode = modules.filter {
            it.group == "com.google.mlkit" && it.name == "barcode-scanning"
        }
        check(bundledBarcode.isEmpty()) {
            "Bundled ML Kit barcode-scanning production graph'a geri döndü " +
                "(useUnbundled düştü mü?): $bundledBarcode"
        }

        val unbundledBarcode = modules.filter {
            it.group == "com.google.android.gms" &&
                it.name == "play-services-mlkit-barcode-scanning"
        }
        check(unbundledBarcode.size == 1) {
            "Production graph tek bir play-services-mlkit-barcode-scanning bekliyor: $unbundledBarcode"
        }
    }
}

tasks.named("check") {
    dependsOn(verifyUnbundledMlKitModels)
}

// Flutter CI `check` çağırmadan assemble/bundle çalıştırıyor; doğrulama
// artefakt kapısına da bağlı.
tasks.matching {
    it.name.startsWith("assemble") || it.name.startsWith("bundle")
}.configureEach {
    dependsOn(verifyUnbundledMlKitModels)
}

android {
    namespace = "com.example.koala"
    // permission_handler_android 14 compileSdk 37 istiyor, Flutter'ın
    // varsayılanı 36. AGP 9.1.1'den eskisi temiz SDK'da `android-37`'yi
    // bulamaz.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.iskoala.koala"
        // flutter_nfc_kit minSdk 24 istiyor; Flutter varsayılanı sessizce
        // değişmesin diye sabit.
        minSdk = 24
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
            manifestPlaceholders += appLinkPlaceholders("staging", manifestHostLines = 1)
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
            manifestPlaceholders += appLinkPlaceholders("production", manifestHostLines = 2)
        }
    }

    buildTypes {
        release {
            // ML Kit'in kullanılmayan dil modelleri için R8 kuralları
            // `proguard-rules.pro`'da; onlarsız release düşüyor.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )

            // Release hiçbir zaman debug anahtarıyla imzalanmaz. Anahtar yoksa
            // çıktı imzasız kalır ve release workflow'u yüklemeden önce durur.
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
