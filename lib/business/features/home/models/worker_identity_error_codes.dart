/// `GET /job-assignments/{id}/worker-identity` ucunun döndürdüğü
/// `errorCode` değerleri (koala-backend#312, 0.9.27).
///
/// Ayrı dosyada duruyor çünkü `test/support/backend_error_codes_test.dart`
/// bu dosyadaki her büyük harfli dizgeyi backend kataloğuyla karşılaştırıyor;
/// `worker_identity.dart`'taki yöntem kodları (`CHIP`, `DOCUMENT`) hata kodu
/// değil ve o karşılaştırmaya girmemeli.
abstract final class WorkerIdentityErrorCodes {
  /// `409` — çalışan kimliğini henüz doğrulamadı; sigorta bildirimi için
  /// önce doğrulamayı tamamlaması gerekiyor.
  static const String workerNotVerified = 'WORKER_IDENTITY_NOT_VERIFIED';

  /// `429` — işverenin saatlik görüntüleme bütçesi doldu.
  static const String tooManyRequests = 'IDENTITY_REVEAL_TOO_MANY_REQUESTS';
}
