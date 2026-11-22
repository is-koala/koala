import 'package:koala/employee/features/auth/models/chip_evidence.dart';
import 'package:koala/employee/features/settings/models/identity_chip_result.dart';
import 'package:koala/employee/features/settings/models/national_identity_number.dart';

/// Kimlik beyanı ve varsa kanıtı; iki hâl tip olarak:
/// - [ManualDeclaration]: kullanıcının yazdığı beş alan, kanıtsız.
/// - [ChipDeclaration]: beş alan [IdentityChipResult]'tan; alan yazacak
///   parametre **yok**, kanıttan ayrışan beyan derlenemez.
sealed class IdentityDeclaration {
  const IdentityDeclaration();

  String get firstName;

  String get lastName;

  String get tcIdentityNumber;

  String get tcDocumentNumber;

  DateTime? get birthDate;

  ChipEvidence? get evidence;

  /// Sunucu ayrıca doğruluyor; bu boşuna bir gidiş dönüşü önler.
  bool get isComplete;
}

final class ManualDeclaration extends IdentityDeclaration {
  const ManualDeclaration({
    required this.firstName,
    required this.lastName,
    required this.tcIdentityNumber,
    required this.tcDocumentNumber,
    this.birthDate,
  });

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
      NationalIdentityNumber.isValid(tcIdentityNumber) &&
      tcDocumentNumber.isNotEmpty &&
      birthDate != null;
}

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

  /// Kart bunları taşımasaydı [IdentityChipResult.parse] sonuç üretmezdi.
  @override
  bool get isComplete => true;
}
