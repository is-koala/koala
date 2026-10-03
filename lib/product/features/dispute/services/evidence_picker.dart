import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:koala/product/features/dispute/models/evidence_file.dart';
import 'package:koala/product/services/picked_file_probe.dart';

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
/// **Metadata istemcide silinmiyor.** `image_picker` yeniden kodlarken EXIF'i
/// (çekim saati, cihaz modeli, varsa GPS) yeni dosyaya kopyalıyor: iOS galeri
/// asıl dosyanın metadata'sını taşıyor, iOS kamerası konum yazmıyor, Android
/// kamerası konum etiketleyebiliyor, Android Photo Picker genellikle konumu
/// çıkarıyor. Kanıtta çekim zamanı ve yeri delil değeri taşıyabilir ama sunucu
/// şu an dosyayı olduğu gibi saklıyor ve karşı taraf indirebiliyor
/// (koala-backend#347 sunucuda ayıklamayı getirecek); ekleme ekranı bu gerçeği
/// kullanıcıya söylüyor.
class EvidencePicker {
  const EvidencePicker();

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

    // Ad verilmiyor: seçicinin geçici adı (`image_picker_8F2A….jpg`) kimseye
    // bir şey söylemiyor; ad yükleme anında üretiliyor
    // ([DisputeEvidencePolicy.accept]).
    return candidateFor(picked.path);
  }

  Future<EvidenceCandidate?> _pickDocument() async {
    final selection = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = selection?.path;
    if (path == null) return null;

    // PDF'in kendi adı kullanıcıya anlamlı ("tutanak.pdf"), korunuyor.
    return candidateFor(path, displayName: selection!.name);
  }

  /// Diskteki dosyadan aday kurar: boyut ve içerik imzası için baş baytlar
  /// ([PickedFileProbe]; kimlik fotoğrafı seçicisiyle ortak okuma).
  static EvidenceCandidate candidateFor(String path, {String? displayName}) {
    final probe = PickedFileProbe.read(path);
    return EvidenceCandidate(
      path: path,
      bytes: probe.bytes,
      head: probe.head,
      displayName: displayName,
    );
  }
}
