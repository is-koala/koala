import 'dart:io';

import 'package:koala/product/constants/app_info.dart';

/// Cihazı sunucuda **adlandıran** başlıklar ("iPhone 14 Pro Max · iOS 18.1 ·
/// Koala 1.1.0"). Kimlik `X-Device-Id`'de; bunlar yoksa cihaz soluk bir adla
/// kalır. Bir kez kurulup her isteğe yazılıyor.
class DeviceHints {
  const DeviceHints({this.model, this.os, this.appVersion});

  /// Donanım modeli. `device_info_plus` olmadığı için şimdilik boş; sunucu
  /// modelsiz ipucunu da kabul ediyor.
  final String? model;

  final String? os;

  /// Uygulama sürümü; `X-App-Version` ile aynı kaynak.
  final String? appVersion;

  static const String modelHeader = 'X-Koala-Device-Model';
  static const String osHeader = 'X-Koala-OS';
  static const String appVersionHeader = 'X-Koala-App-Version';

  static const DeviceHints none = DeviceHints();

  factory DeviceHints.current() {
    return DeviceHints(
      os: describeOs(
        operatingSystem: Platform.operatingSystem,
        operatingSystemVersion: Platform.operatingSystemVersion,
      ),
      appVersion: AppInfo.version,
    );
  }

  /// `Platform` değerlerini kısa ada çevirir (`iOS 18.1`). Android'de
  /// `operatingSystemVersion` çekirdek sürümünü taşıyor, o yüzden yalnız
  /// `Android` yazılıyor.
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

  static final RegExp _versionNumber = RegExp(r'(\d+(?:\.\d+)+)');

  /// Boş değer başlık olarak gönderilmiyor.
  Map<String, String> get headers => {
    if (_hasText(model)) modelHeader: model!.trim(),
    if (_hasText(os)) osHeader: os!.trim(),
    if (_hasText(appVersion)) appVersionHeader: appVersion!.trim(),
  };

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;
}
