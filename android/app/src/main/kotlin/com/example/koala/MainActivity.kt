package com.example.koala

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MAPS_AVAILABILITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> result.success(mapsApiKeyPresent())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Manifestteki `com.google.android.geo.API_KEY` meta-verisi dolu mu.
     * Android'de anahtar boşken harita çökmez, boş kalır; Dart yine de yer
     * tutucu göstersin diye iki platform aynı kanaldan aynı cevabı veriyor
     * (is-koala/koala#172).
     */
    private fun mapsApiKeyPresent(): Boolean {
        val info = try {
            packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
        } catch (_: PackageManager.NameNotFoundException) {
            return false
        }
        val key = info.metaData?.getString(MAPS_API_KEY_META_DATA)
        return !key.isNullOrBlank()
    }

    private companion object {
        /** `lib/product/services/maps_availability.dart` ile aynı ad. */
        const val MAPS_AVAILABILITY_CHANNEL = "com.iskoala.koala/maps_availability"
        const val MAPS_API_KEY_META_DATA = "com.google.android.geo.API_KEY"
    }
}
