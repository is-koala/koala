import 'package:koala/employee/features/auth/models/current_user.dart';

/// `/auth/verify-registration-token` yanıtı: şifre belirleme token'ı ve kayıt
/// tipi.
class RegistrationVerification {
  const RegistrationVerification({
    required this.setPasswordToken,
    required this.isEmployer,
  });

  final String setPasswordToken;

  /// İşverense şifreden sonra şirket bilgilerine gidilir.
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
