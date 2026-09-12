import 'package:koala/employee/features/auth/models/chip_evidence.dart';
import 'package:koala/employee/features/settings/models/identity_chip_result.dart';

/// Kimlik doğrulama isteğinin beş beyan alanı ve varsa yanına eklenen kanıt.
///
/// İki hâli var ve ikisi de tiptir, bayrak değil:
///
/// - [ManualDeclaration] — kullanıcının yazdığı beş alan, kanıtsız. NFC'si
///   olmayan telefonun ve çipi okutmayan kullanıcının yolu.
/// - [ChipDeclaration] — beş alanın da [IdentityChipResult]'tan türediği
///   beyan. Alan yazacak bir kurucu parametresi **yok**; kanıt varken ondan
///   ayrışan bir beyan bu tiple derlenemiyor. Kabul maddesinin
///   ("kanıt varken uyuşmaz beyan üretilemez") karşılığı burada.
///
/// `IDENTITY_PASSIVE_AUTH_ENABLED` sunucuda kapalıyken ikisi de kabul
/// ediliyor; bayrak açıldığında sunucu beyanı DG1/DG11 ile karşılaştıracak
/// ve [ChipDeclaration] o karşılaştırmadan tanımı gereği geçiyor.
sealed class IdentityDeclaration {
  const IdentityDeclaration();

  String get firstName;

  String get lastName;

  String get tcIdentityNumber;

  String get tcDocumentNumber;

  DateTime? get birthDate;

  /// İstek gövdesine eklenecek çip kanıtı; elle beyanda `null`.
  ChipEvidence? get evidence;

  /// Gönderilebilir mi. Sunucu deseni ayrıca doğruluyor; buradaki kontrol
  /// kullanıcıyı boşuna bir gidiş dönüşten kurtarıyor.
  bool get isComplete;
}

/// Kullanıcının kendi yazdığı beyan.
final class ManualDeclaration extends IdentityDeclaration {
  const ManualDeclaration({
    required this.firstName,
    required this.lastName,
    required this.tcIdentityNumber,
    required this.tcDocumentNumber,
    this.birthDate,
  });

  /// TC kimlik numarası tam 11 hane.
  static const int tcIdentityLength = 11;

  @override
  final String firstName;

  @override
  final String lastName;

  @override
  final String tcIdentityNumber;

  @override
  final String tcDocumentNumber;

  @override
  final DateTime? birthDate;

  @override
  ChipEvidence? get evidence => null;

  @override
  bool get isComplete =>
      firstName.isNotEmpty &&
      lastName.isNotEmpty &&
      tcIdentityNumber.length == tcIdentityLength &&
      tcDocumentNumber.isNotEmpty &&
      birthDate != null;
}

/// Çipten türeyen beyan: beş alan da kanıtın kendisinden okunuyor.
final class ChipDeclaration extends IdentityDeclaration {
  const ChipDeclaration(this.chip);

  final IdentityChipResult chip;

  @override
  String get firstName => chip.holder.firstName;

  @override
  String get lastName => chip.holder.lastName;

  @override
  String get tcIdentityNumber => chip.holder.nationalIdentityNumber;

  @override
  String get tcDocumentNumber => chip.holder.documentNumber;

  @override
  DateTime get birthDate => chip.holder.birthDate;

  @override
  ChipEvidence get evidence => chip.evidence;

  /// Çipten gelen alanlar boş olamaz: kart bunları taşımasaydı
  /// [IdentityChipResult.parse] hiç sonuç üretmezdi.
  @override
  bool get isComplete => true;
}
