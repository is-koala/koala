import 'package:koala/product/network/json_field.dart';

/// Kimliğin nasıl doğrulandığı. Backend `IdentityVerificationMethod`
/// karşılığı; işveren sigorta bildiriminde hangi kanıta dayandığını görüyor.
enum IdentityVerificationMethod {
  /// Çipli kimlik kartından NFC ile okundu.
  chip('CHIP', 'Çipli kimlik'),

  /// Kimlik belgesinin fotoğrafı incelendi.
  document('DOCUMENT', 'Belge incelemesi'),

  /// Sunucunun gönderdiği değer bu sürümde bilinmiyor. Yöntem gösterilmez
  /// ama kimlik bilgileri yine okunur; eksik bir etiket için ekran
  /// kapanmamalı.
  unknown('', 'Bilinmiyor');

  const IdentityVerificationMethod(this.code, this.displayName);

  final String code;
  final String displayName;

  static IdentityVerificationMethod fromCode(Object? value) {
    return IdentityVerificationMethod.values.firstWhere(
      (method) => method.code == value && method != unknown,
      orElse: () => unknown,
    );
  }
}

/// İşe alınan çalışanın sigorta bildirimi için açılan kimlik bilgileri.
///
/// `GET /job-assignments/{id}/worker-identity` yanıtı (`WorkerIdentityDto`,
/// koala-backend#312). Yalnız bellekte ve süreli tutulur: sayfa 60 saniye
/// sonra ya da kapanınca siler; diske, günlüğe ve provider'a yazılmaz.
/// `toString` bilerek alanları yazmıyor — bir hata günlüğüne TCKN düşmesin.
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

  /// Sunucu `LocalDate` gönderiyor; saat yok.
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
