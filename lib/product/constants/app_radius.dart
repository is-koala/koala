import 'package:flutter/widgets.dart';

/// Köşe yuvarlaklığı sabitleri.
///
/// Hem `double` hem hazır `BorderRadius` karşılıkları var; `BoxDecoration` ve
/// `ClipRRect` için hazır olanı kullan, tek köşe gerektiğinde `double`'ı.
class AppRadius {
  /// Buton, arama kutusu ve textfield gibi tam yuvarlak duran bileşenler.
  static const double primary = 36.0;

  /// Kart, bottom sheet ve büyük kutular.
  static const double secondary = 20.0;

  /// Liste satırındaki kare görsel ve küçük kutular. Kartın kendi
  /// yarıçapının içine oturduğu için ondan küçük; eşit olsaydı iç köşe
  /// dıştakinden daha yuvarlak görünürdü.
  static const double inner = 12.0;

  /// Rozet, etiket ve küçük durum kutuları.
  static const double small = 8.0;

  /// Kutunun yarı yüksekliğini aştığı için çizimde otomatik olarak tam
  /// yuvarlak (stadium) hâline iner. Yükseklik değişince peşinden
  /// güncellemek gerekmez — sabit bir yarıçapın aksine.
  static const double stadium = 999.0;

  // ------------------------------------------------------- BorderRadius'lar

  static const BorderRadius primaryCircular = BorderRadius.all(
    Radius.circular(primary),
  );

  static const BorderRadius secondaryCircular = BorderRadius.all(
    Radius.circular(secondary),
  );

  static const BorderRadius innerCircular = BorderRadius.all(
    Radius.circular(inner),
  );

  static const BorderRadius smallCircular = BorderRadius.all(
    Radius.circular(small),
  );

  static const BorderRadius stadiumCircular = BorderRadius.all(
    Radius.circular(stadium),
  );

  static const BorderRadius primaryBottom = BorderRadius.only(
    bottomLeft: Radius.circular(primary),
    bottomRight: Radius.circular(primary),
  );

  static const BorderRadius secondaryBottom = BorderRadius.only(
    bottomLeft: Radius.circular(secondary),
    bottomRight: Radius.circular(secondary),
  );

  /// Bottom sheet'in üst köşeleri. Karttan geniş: sheet ekranın alt kenarına
  /// yapıştığı için köşeleri daha belirgin olmalı.
  static const double sheet = 24.0;
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
}
