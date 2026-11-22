import 'dart:io';

/// Seçilen dosyanın boyutu ve ilk baytları; biçim içerik imzasından tanınıyor.
class PickedFileProbe {
  const PickedFileProbe({required this.bytes, required this.head});

  final int bytes;

  final List<int> head;

  /// PDF 4, JPEG 3, PNG 8; HEIF'in `....ftyp` kutusu için 12.
  static const int headLength = 12;

  /// **Eşzamanlı** okur; sahte saatli widget testlerinde takılmıyor.
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
