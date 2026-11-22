import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Cihazı sunucuya tanıtan kimlik.
///
/// Backend oturumu `X-Device-Id`'ye bağlıyor ve tutmazsa oturumu kapatıyor;
/// kimlik kurulum boyunca aynı kalmalı. Başlık yoksa aynı platformdaki bütün
/// kurulumlar tek cihaz sayılır.
class DeviceIdentity {
  DeviceIdentity._internal();

  static final DeviceIdentity _instance = DeviceIdentity._internal();

  factory DeviceIdentity() => _instance;

  @visibleForTesting
  DeviceIdentity.fresh();

  static const String deviceIdHeader = 'X-Device-Id';

  /// Çıkışta silinmiyor: kimlik oturuma değil kuruluma ait.
  static const String _deviceIdKey = 'koala_device_id';

  /// Backend'in kabul ettiği `[A-Za-z0-9._:-]{8,128}` ile uyumlu.
  static const String _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  static const int _idLength = 32;

  String? _cachedDeviceId;

  /// Kuruluma özel kalıcı kimlik; ilk çağrıda üretilir.
  Future<String> deviceId() async {
    final cached = _cachedDeviceId;
    if (cached != null) return cached;

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_deviceIdKey);
    if (stored != null) {
      _cachedDeviceId = stored;
      return stored;
    }

    final generated = _generateId();
    await prefs.setString(_deviceIdKey, generated);
    _cachedDeviceId = generated;
    return generated;
  }

  static String _generateId() {
    final random = Random.secure();
    return List.generate(
      _idLength,
      (_) => _alphabet[random.nextInt(_alphabet.length)],
    ).join();
  }

  /// Cihazın görünen adı için; kimlik taşımıyor.
  static String get userAgent {
    if (Platform.isAndroid) return 'Koala (Android)';
    if (Platform.isIOS) return 'Koala (iOS)';
    return 'Koala';
  }
}
