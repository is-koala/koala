import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:koala/product/features/dispute/models/evidence_file.dart';

/// Kanıtın nereden alınacağı.
enum EvidenceSource {
  /// Cihaz kamerası (arka).
  camera,

  /// Galeri / sistem fotoğraf seçicisi.
  gallery,

  /// Belge seçicisi; yalnız PDF.
  document,
}

/// Kanıt dosyasını kameradan, galeriden ya da belge seçicisinden alan sınır.
///
/// `image_picker` ve `file_picker` zaten pubspec'te (şirket logosu, kimlik
/// fotoğrafları ve özgeçmiş için eklenmişlerdi); **yeni paket yok**. Sınıf
/// olarak duruyor ki testler yerli eklenti olmadan bir sahteyle değiştirsin.
///
/// Fotoğrafa ölçek ve kalite **her zaman** veriliyor
/// ([DisputeEvidencePolicy.maxDimension]): dosya sunucu sınırının altında
/// kalıyor ve iPhone'un HEIC karesi JPEG'e çevriliyor; sunucu HEIC açamıyor.
///
/// **Metadata silinmiyor.** `image_picker` yeniden kodlarken EXIF'i (çekim
/// saati, cihaz modeli ve — kamerada konum açıksa — GPS) yeni dosyaya
/// kopyalıyor; uygulamanın bütün fotoğraf yüklemeleri aynı yoldan gidiyor.
/// Kanıtta çekim zamanı ve yeri delil değeri taşıyabiliyor ve sunucu dosyayı
/// olduğu gibi saklıyor; ekleme ekranı bunu kullanıcıya söylüyor.
class EvidencePicker {
  const EvidencePicker({DateTime Function()? clock}) : _clock = clock;

  final DateTime Function()? _clock;

  /// Dosyayı alır; kullanıcı vazgeçtiyse `null`. Dönen aday henüz sınırlardan
  /// geçmedi: biçim ve boyut kararı [DisputeEvidencePolicy.accept]'in işi.
  Future<EvidenceCandidate?> pick(EvidenceSource source) async {
    return switch (source) {
      EvidenceSource.camera => _pickPhoto(ImageSource.camera),
      EvidenceSource.gallery => _pickPhoto(ImageSource.gallery),
      EvidenceSource.document => _pickDocument(),
    };
  }

  Future<EvidenceCandidate?> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: DisputeEvidencePolicy.maxDimension,
      maxHeight: DisputeEvidencePolicy.maxDimension,
      imageQuality: DisputeEvidencePolicy.quality,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (picked == null) return null;

    // Seçicinin geçici adı (`image_picker_8F2A….jpg`) kullanıcıya da
    // sunucuya anlamlı gelmiyor; çekim anından ad üretiliyor.
    return candidateFor(picked.path, displayName: photoName(_now()));
  }

  Future<EvidenceCandidate?> _pickDocument() async {
    final selection = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = selection?.path;
    if (path == null) return null;

    return candidateFor(path, displayName: selection!.name);
  }

  DateTime _now() => (_clock ?? DateTime.now)();

  /// `foto-20261003-104231`: aynı uyuşmazlıkta birkaç fotoğraf birbirinden
  /// ayırt edilsin diye saniyeye kadar.
  static String photoName(DateTime moment) {
    String two(int value) => value.toString().padLeft(2, '0');
    return 'foto-${moment.year}${two(moment.month)}${two(moment.day)}'
        '-${two(moment.hour)}${two(moment.minute)}${two(moment.second)}';
  }

  /// Diskteki dosyadan aday kurar: boyut ve içerik imzası için baş baytlar.
  ///
  /// Eşzamanlı okuma: dosyanın tamamı değil ilk on iki baytı; sahte saatli
  /// widget testlerinde de eşzamansız IO gibi takılmıyor.
  static EvidenceCandidate candidateFor(
    String path, {
    required String displayName,
  }) {
    final handle = File(path).openSync();
    try {
      return EvidenceCandidate(
        path: path,
        bytes: handle.lengthSync(),
        head: handle.readSync(EvidenceFormat.signatureLength),
        displayName: displayName,
      );
    } finally {
      handle.closeSync();
    }
  }
}
