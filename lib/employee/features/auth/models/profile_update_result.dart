import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/models/pending_verification.dart';

/// `PATCH /users/me` yanıtı (`UserUpdateResponseDto`).
///
/// Güncel kullanıcının yanında, doğrulama beklediği için henüz yazılmamış
/// alanları da taşıyor.
class ProfileUpdateResult {
  const ProfileUpdateResult({
    required this.user,
    this.pendingVerifications = const [],
  });

  final CurrentUser user;
  final List<PendingVerification> pendingVerifications;

  factory ProfileUpdateResult.fromJson(Map<String, dynamic> json) {
    final pending = json['pendingVerifications'];

    return ProfileUpdateResult(
      user: CurrentUser.fromJson(json['user']! as Map<String, dynamic>),
      pendingVerifications: pending is List
          ? pending
                .whereType<Map<String, dynamic>>()
                .map(PendingVerification.fromJson)
                .toList()
          : const [],
    );
  }
}
