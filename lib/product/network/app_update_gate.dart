import 'package:flutter/foundation.dart';

/// Sunucunun "bu sürüm desteklenmiyor" (`426`) cevabını taşıyan tek nokta. Her
/// uçtan gelebildiği için ekranlarda tek tek karşılanmıyor. Kapı tek yönlü:
/// uygulama içinde sürüm değişmez.
class AppUpdateGate {
  AppUpdateGate._();

  static final AppUpdateGate _instance = AppUpdateGate._();

  factory AppUpdateGate() => _instance;

  /// Sunucunun mesajı; `null` ise kapı açık.
  final ValueNotifier<String?> message = ValueNotifier<String?>(null);

  bool get isBlocked => message.value != null;

  /// Kapıyı kapatır; aynı mesajla dinleyicileri yeniden uyandırmaz.
  void block(String? serverMessage) {
    final text = serverMessage == null || serverMessage.trim().isEmpty
        ? 'Lütfen uygulamayı güncelleyin.'
        : serverMessage;

    if (message.value == text) return;
    message.value = text;
  }

  @visibleForTesting
  void reset() => message.value = null;
}
