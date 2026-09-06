import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/auth/models/agreement_version.dart';
import 'package:koala/employee/features/auth/models/consent_decision.dart';
import 'package:koala/product/models/account_deletion.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Sözleşmeler ve onaylar.
///
/// Kayıt akışının parçası olduğu için `auth` altında duruyor; hesap silme ve
/// onay geçmişi ekranları da buraya bağlanacak.
class LegalService {
  LegalService._(this._apiClient);

  static final LegalService _instance = LegalService._(ApiClient());

  factory LegalService() => _instance;

  @visibleForTesting
  factory LegalService.withClient(ApiClient apiClient) {
    return LegalService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Yürürlükteki sözleşme sürümleri. Token istemiyor; kayıt sırasında
  /// gösterilen onay kutuları bu listeden çiziliyor.
  Future<List<AgreementVersion>> fetchCurrentAgreements() {
    return _apiClient.get<List<AgreementVersion>>(
      ApiPaths.agreements,
      parse: (data) => data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(AgreementVersion.fromJson)
                .toList()
          : const [],
    );
  }

  /// Oturum açmış kullanıcının onaylarını günceller.
  ///
  /// Kayıt sırasındaki onaylar bu uçtan değil, `complete-registration`
  /// gövdesinden gidiyor.
  Future<void> recordConsents(List<ConsentDecision> decisions) {
    return _apiClient.postWithoutData(
      ApiPaths.consents,
      body: decisions.map((decision) => decision.toJson()).toList(),
    );
  }

  /// Hesap silme talebi oluşturur.
  Future<AccountDeletion> requestAccountDeletion({String? reason}) {
    return _apiClient.post<AccountDeletion>(
      ApiPaths.accountDeletion,
      body: {'reason': reason},
      parse: (data) => AccountDeletion.fromJson(data as Map<String, dynamic>),
    );
  }
}
