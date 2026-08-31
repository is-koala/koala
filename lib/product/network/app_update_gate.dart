import 'package:flutter/foundation.dart';

/// Sunucunun "bu sürüm artık desteklenmiyor" cevabını taşıyan tek nokta.
///
/// `MinimumAppVersionFilter` **her uçtan** `426` döndürebiliyor, yani hatayı
/// tek tek ekranlarda karşılamanın anlamı yok: hangi istek yerse yesin
/// sonuç aynı — kullanıcının uygulamayı güncellemesi gerekiyor.
///
/// Kapı **tek yönlü**: bir kez kapandıktan sonra açılmıyor. Uygulama içinde
/// sürümün değişmesi mümkün değil, dolayısıyla "belki düzelmiştir" diye
/// tekrar denemenin de karşılığı yok.
class AppUpdateGate {
  AppUpdateGate._();

  static final AppUpdateGate _instance = AppUpdateGate._();

  factory AppUpdateGate() => _instance;

  /// Sunucunun gönderdiği mesaj; `null` ise kapı açık.
  final ValueNotifier<String?> message = ValueNotifier<String?>(null);

  bool get isBlocked => message.value != null;

  /// Kapıyı kapatır. Aynı mesajla ikinci kez çağrılması dinleyicileri
  /// gereksiz uyandırmasın diye değer aynıysa yazılmıyor.
  void block(String? serverMessage) {
    final text = serverMessage == null || serverMessage.trim().isEmpty
        ? 'Lütfen uygulamayı güncelleyin.'
        : serverMessage;

    if (message.value == text) return;
    message.value = text;
  }

  /// Yalnızca testler için; uygulama akışında kapı açılmıyor.
  @visibleForTesting
  void reset() => message.value = null;
}
