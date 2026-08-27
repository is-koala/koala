import 'package:koala/employee/features/auth/models/current_user.dart';

/// `/auth/verify-registration-token` yanıtı.
///
/// E-postadaki bağlantıdan gelen token'ın karşılığı: şifre belirlemek için
/// kullanılacak ikinci token ve kaydın iş veren kaydı olup olmadığı.
class RegistrationVerification {
  const RegistrationVerification({
    required this.setPasswordToken,
    required this.isEmployer,
  });

  /// `/auth/complete-registration` çağrısına gönderilecek token.
  final String setPasswordToken;

  /// Kayıt iş veren olarak başlatıldıysa `true`. Şifre adımından sonra
  /// şirket bilgileri ekranına gidilip gidilmeyeceğini bu belirliyor.
  final bool isEmployer;

  factory RegistrationVerification.fromJson(Map<String, dynamic> json) {
    return RegistrationVerification(
      setPasswordToken: json['setPasswordToken'] as String,
      isEmployer: CurrentUser.readEmployerFlag(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {'setPasswordToken': setPasswordToken, 'isEmployer': isEmployer};
  }
}
