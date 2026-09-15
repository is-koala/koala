import 'dart:io';

import 'package:koala/product/constants/app_info.dart';

/// Cihazı sunucuda **adlandıran** üç başlık (koala-backend#306).
///
/// `X-Device-Id` kimlik, bunlar açıklama: sunucu oturum listesinde
/// "iPhone 14 Pro Max · iOS 18.1 · Koala 1.1.0" gibi gerçek bir cihaz adı
/// yazabilsin diye. Başlık yoksa sunucu `User-Agent`'a düşüyor ve cihaz
/// "iPhone" gibi soluk bir adla kalıyor; yani göndermemek kırmayan ama
/// tanınmaz bırakan bir eksik.
///
/// Değerler her zaman aynı: cihaz oturum boyunca değişmiyor. Bu yüzden bir
/// kez kuruluyor ([DeviceHints.current]) ve `DeviceInterceptor` her isteğe
/// aynı nesneyi yazıyor; sunucu yalnızca giriş, kayıt tamamlama ve yenileme
/// isteklerinde okuyor, diğerlerinde başlığı görmezden geliyor.
class DeviceHints {
  const DeviceHints({this.model, this.os, this.appVersion});

  /// Donanım modeli (`iPhone15,3`). Projede `device_info_plus` yok ve yeni
  /// bağımlılık eklemek onay istiyor; o gelene kadar boş ve başlık hiç
  /// gönderilmiyor. Sunucu modelsiz ipucunu da kabul ediyor
  /// (`describesDevice` işletim sistemiyle de doğru).
  final String? model;

  /// İşletim sistemi ve sürümü (`iOS 18.1`).
  final String? os;

  /// Uygulama sürümü (`1.1.0`). `X-App-Version` ile aynı kaynaktan
  /// ([AppInfo.version]); o başlık sürüm kapısına, bu cihaz adına gidiyor.
  final String? appVersion;

  static const String modelHeader = 'X-Koala-Device-Model';
  static const String osHeader = 'X-Koala-OS';
  static const String appVersionHeader = 'X-Koala-App-Version';

  /// Hiçbir başlık taşımayan ipucu.
  static const DeviceHints none = DeviceHints();

  /// Çalışan cihazın ipuçları.
  factory DeviceHints.current() {
    return DeviceHints(
      os: describeOs(
        operatingSystem: Platform.operatingSystem,
        operatingSystemVersion: Platform.operatingSystemVersion,
      ),
      appVersion: AppInfo.version,
    );
  }

  /// `Platform` değerlerini sunucunun göstereceği kısa ada çevirir.
  ///
  /// `Platform.operatingSystemVersion` iOS'ta `Version 18.1 (Build 22B83)`
  /// veriyor; sürüm numarası alınıp `iOS 18.1` yazılıyor. Android'de aynı
  /// alan **çekirdek** sürümünü (`Linux 5.10.43-android12-9 …`) taşıyor —
  /// oradaki `android12` çekirdek dalı, işletim sistemi sürümü değil;
  /// yanıltıcı bir sayı yazmaktansa yalnız `Android` gönderiliyor. Sürüm
  /// çıkarılamayan her platformda da yalnız ad kalıyor.
  static String describeOs({
    required String operatingSystem,
    required String operatingSystemVersion,
  }) {
    final name = switch (operatingSystem) {
      'ios' => 'iOS',
      'android' => 'Android',
      'macos' => 'macOS',
      'windows' => 'Windows',
      'linux' => 'Linux',
      _ => operatingSystem,
    };

    if (operatingSystem == 'android') return name;

    final version = _versionNumber.firstMatch(operatingSystemVersion)?.group(1);
    return version == null ? name : '$name $version';
  }

  /// `Version 18.1 (Build …)` ya da `18.1.2` içindeki sürüm numarası.
  static final RegExp _versionNumber = RegExp(r'(\d+(?:\.\d+)+)');

  /// İsteğe yazılacak başlıklar. Boş değer başlık olarak gitmiyor: sunucu
  /// boş başlığı yok sayıyor ama gönderilmemesi daha temiz.
  Map<String, String> get headers => {
    if (_hasText(model)) modelHeader: model!.trim(),
    if (_hasText(os)) osHeader: os!.trim(),
    if (_hasText(appVersion)) appVersionHeader: appVersion!.trim(),
  };

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;
}
