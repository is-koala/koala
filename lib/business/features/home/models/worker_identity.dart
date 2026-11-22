import 'package:koala/product/network/json_field.dart';

/// Kimliğin nasıl doğrulandığı; işveren sigorta bildiriminde hangi kanıta
/// dayandığını görüyor.
enum IdentityVerificationMethod {
  chip('CHIP', 'Çipli kimlik'),

  document('DOCUMENT', 'Belge incelemesi'),

  /// Bilinmeyen yöntem: etiketi yok ama kimlik yine okunur.
  unknown('', null);

  const IdentityVerificationMethod(this.code, this.displayName);

  final String code;

  final String? displayName;

  static IdentityVerificationMethod fromCode(Object? value) {
    return IdentityVerificationMethod.values.firstWhere(
      (method) => method.code == value && method != unknown,
      orElse: () => unknown,
    );
  }
}

/// Sigorta bildirimi için açılan kimlik bilgileri. Yalnız bellekte ve süreli
/// tutulur (60 sn); diske, günlüğe ve provider'a yazılmaz. `toString` alanları
/// yazmıyor ki günlüğe TCKN düşmesin.
class WorkerIdentity {
  const WorkerIdentity({
    required this.fullName,
    required this.tcIdentityNumber,
    required this.birthDate,
    required this.verifiedAt,
    required this.verificationMethod,
  });

  final String fullName;
  final String tcIdentityNumber;

  final DateTime? birthDate;
  final DateTime? verifiedAt;
  final IdentityVerificationMethod verificationMethod;

  factory WorkerIdentity.fromJson(Map<String, dynamic> json) {
    return WorkerIdentity(
      fullName: json['fullName'] as String? ?? '',
      tcIdentityNumber: JsonField.requiredString(
        json['tcIdentityNumber'],
        'tcIdentityNumber',
      ),
      birthDate: JsonField.dateOrNull(json['birthDate']),
      verifiedAt: JsonField.dateOrNull(json['verifiedAt']),
      verificationMethod: IdentityVerificationMethod.fromCode(
        json['verificationMethod'],
      ),
    );
  }

  @override
  String toString() => 'WorkerIdentity(gizli)';
}
