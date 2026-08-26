/// Sayı biçimlendirme yardımcıları.
extension PriceExtension on num {
  /// Ücreti binlik ayracıyla yazar: `1500` → `1.500`.
  ///
  /// Kuruş gösterilmiyor; ilan ücretleri tam sayı olarak giriliyor.
  String get asPrice => toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );
}
