/// Worker-identity ucunun hata kodları. Ayrı dosyada, çünkü
/// `backend_error_codes_test` buradaki dizgeleri kataloğa karşı sabitliyor;
/// `CHIP` gibi yöntem kodları girmemeli.
abstract final class WorkerIdentityErrorCodes {
  /// `409`: çalışan kimliğini henüz doğrulamadı.
  static const String workerNotVerified = 'WORKER_IDENTITY_NOT_VERIFIED';

  /// `429`: saatlik görüntüleme bütçesi doldu.
  static const String tooManyRequests = 'IDENTITY_REVEAL_TOO_MANY_REQUESTS';
}
