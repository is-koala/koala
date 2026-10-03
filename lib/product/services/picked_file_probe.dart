import 'dart:io';

/// Seçicinin verdiği dosyanın boyutu ve ilk baytları.
///
/// Kimlik fotoğrafları ve uyuşmazlık kanıtı aynı şeyi yapıyor: dosyanın
/// biçimi **içerik imzasından** tanınıyor ve boyut sınırı seçim anında
/// bakılıyor. İkisinin de seçicisi bunu buradan alıyor; iki ayrı okuma kodu
/// zamanla ayrışırdı.
class PickedFileProbe {
  const PickedFileProbe({required this.bytes, required this.head});

  /// Dosyanın boyutu.
  final int bytes;

  /// Dosyanın ilk [headLength] baytı (daha kısaysa hepsi).
  final List<int> head;

  /// İmzayı tanımaya yeten baş bayt sayısı: PDF 4, JPEG 3, PNG 8; HEIF'in
  /// `....ftyp` kutusunu (iPhone'un kabul edilmeyen biçimi) görmek için 12.
  static const int headLength = 12;

  /// Diskteki dosyayı **eşzamanlı** okur: dosyanın tamamı değil boyutu ve ilk
  /// [headLength] baytı. Sahte saatli widget testlerinde eşzamansız IO gibi
  /// takılmıyor.
  static PickedFileProbe read(String path) {
    final handle = File(path).openSync();
    try {
      return PickedFileProbe(
        bytes: handle.lengthSync(),
        head: handle.readSync(headLength),
      );
    } finally {
      handle.closeSync();
    }
  }
}
