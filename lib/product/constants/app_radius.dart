import 'package:flutter/widgets.dart';

/// Köşe yuvarlaklıkları. `BoxDecoration`/`ClipRRect` için hazır
/// `BorderRadius`'ı, tek köşe için `double`'ı kullan.
class AppRadius {
  /// Buton, arama kutusu, textfield.
  static const double primary = 36.0;

  /// Kart, bottom sheet, büyük kutular.
  static const double secondary = 20.0;

  /// Kartın içindeki görsel ve kutular; kartla eşit olsa iç köşe dıştakinden
  /// yuvarlak görünürdü.
  static const double inner = 12.0;

  static const double small = 8.0;

  /// Yarı yüksekliği aştığı için her boyda tam yuvarlak (stadium) çizilir.
  static const double stadium = 999.0;

  /// Sohbetteki 40'lık avatar; 60'lık avatardaki [secondary] oranı bu ölçekte
  /// 14.
  static const double avatar = 14.0;

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

  /// Ekranın alt kenarına yapıştığı için karttan geniş.
  static const double sheet = 24.0;
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
}
