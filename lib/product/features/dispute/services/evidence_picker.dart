import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:koala/product/features/dispute/models/evidence_file.dart';
import 'package:koala/product/services/picked_file_probe.dart';

enum EvidenceSource {
  camera,

  gallery,

  /// Belge seçicisi; yalnız PDF.
  document,
}

/// Kanıtı kameradan, galeriden ya da belge seçicisinden alır; testler
/// sahtesiyle değiştirsin diye sınıf.
///
/// Fotoğrafa ölçek ve kalite her zaman veriliyor: dosya sınırın altında kalıyor
/// ve HEIC JPEG'e çevriliyor. **Metadata (EXIF, varsa GPS) istemcide
/// silinmiyor**; sunucu dosyayı olduğu gibi saklıyor (koala-backend#347) ve
/// ekleme ekranı bunu söylüyor.
class EvidencePicker {
  const EvidencePicker();

  /// Vazgeçilirse `null`. Biçim ve boyut kararı
  /// [DisputeEvidencePolicy.accept]'in.
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

    // Seçicinin geçici adı bir şey söylemiyor; ad yükleme anında üretilir.
    return candidateFor(picked.path);
  }

  Future<EvidenceCandidate?> _pickDocument() async {
    final selection = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = selection?.path;
    if (path == null) return null;

    // PDF'in kendi adı anlamlı, korunuyor.
    return candidateFor(path, displayName: selection!.name);
  }

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
