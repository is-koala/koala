import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/employee/features/jobs/models/cancellation.dart';
import 'package:koala/employee/features/jobs/models/dispute.dart';
import 'package:koala/employee/features/jobs/models/work_session.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';
import 'package:koala/product/utils/coordinate_precision.dart';

/// Atama uçları.
///
/// Başvuru kabul edilene kadar iş bir `JobApplication`; kabul edildikten
/// sonrası bir atama ve buradan yönetiliyor. Başvurunun kendisi
/// `JobApplicationService`'te kalıyor — backend'in ikisini ayırdığı yer orası.
///
/// Sınıfın tamamı çalışana ait değil: mesai oturumlarını, iptali ve
/// uyuşmazlıkları iki taraf da okuyup yazabiliyor, o yüzden işveren tarafı
/// da bu servisi çağırıyor. Yalnızca [checkIn] ve [checkOut] işçiye, [respond]
/// atamanın çalışanına özel — diğerlerinde sunucu tarafı zaten ayırt ediyor.
class AssignmentService {
  AssignmentService._(this._apiClient);

  static final AssignmentService _instance = AssignmentService._(ApiClient());

  factory AssignmentService() => _instance;

  @visibleForTesting
  factory AssignmentService.withClient(ApiClient apiClient) {
    return AssignmentService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Kabul edilmiş başvuruların dönüştüğü işler.
  Future<AssignmentPage> fetchMyAssignments({int page = 0, int size = 20}) {
    return _apiClient.get<AssignmentPage>(
      ApiPaths.myAssignments,
      queryParameters: {'page': page, 'size': size},
      parse: (data) => AssignmentPage.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Tek bir atamayı kimliğiyle okur.
  ///
  /// Sunucu yalnızca atamanın taraflarına açıyor; taraf olmayan `404`
  /// alıyor. İş detayı bir eylemden sonra bütün listeyi değil bu kaydı
  /// tazeliyor — sayfalamadan bağımsız ve tek istek.
  Future<Assignment> fetchAssignment(String assignmentId) {
    return _apiClient.get<Assignment>(
      ApiPaths.jobAssignment(assignmentId),
      parse: (data) => Assignment.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Mesaiye başlar ve açılan oturumu döndürür.
  ///
  /// Konum isteğe bağlı: sunucu gövdesiz isteği de kabul ediyor, o yüzden
  /// konum alınamadığında giriş engellenmiyor — koordinatlar hiç
  /// gönderilmiyor.
  ///
  /// `409` üç sebeple gelebiliyor: atama çalışmaya açık değil, para henüz
  /// emanete alınmamış, ya da zaten açık bir oturum var. Mesajı sunucu
  /// Türkçe veriyor.
  Future<WorkSession> checkIn({
    required String assignmentId,
    double? latitude,
    double? longitude,
    String? clientEventId,
    DateTime? capturedAt,
  }) {
    return _apiClient.post<WorkSession>(
      ApiPaths.assignmentCheckIn(assignmentId),
      body: _checkPointBody(
        latitude: latitude,
        longitude: longitude,
        clientEventId: clientEventId,
        capturedAt: capturedAt,
      ),
      parse: (data) => WorkSession.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Açık mesai oturumunu kapatır.
  ///
  /// Sunucu çalışılan dakikayı burada yazıyor ve atamanın `workHours`
  /// alanını bütün oturumların toplamından türetiyor. Açık oturum yoksa
  /// `409`.
  Future<WorkSession> checkOut({
    required String assignmentId,
    double? latitude,
    double? longitude,
    String? clientEventId,
    DateTime? capturedAt,
  }) {
    return _apiClient.post<WorkSession>(
      ApiPaths.assignmentCheckOut(assignmentId),
      body: _checkPointBody(
        latitude: latitude,
        longitude: longitude,
        clientEventId: clientEventId,
        capturedAt: capturedAt,
      ),
      parse: (data) => WorkSession.fromJson(data! as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> _checkPointBody({
    required double? latitude,
    required double? longitude,
    required String? clientEventId,
    required DateTime? capturedAt,
  }) {
    if ((clientEventId == null) != (capturedAt == null)) {
      throw ArgumentError('clientEventId ve capturedAt birlikte verilmelidir.');
    }

    // Konum varsa altı ondalıkla gider: sunucu koordinatı o kesinlikte
    // saklayıp geri veriyor, kuyruğun eşleştirmesi de aynı kesinliğe bakıyor.
    return {
      'latitude': ?_rounded(latitude),
      'longitude': ?_rounded(longitude),
      'clientEventId': ?clientEventId,
      'capturedAt': ?capturedAt?.toUtc().toIso8601String(),
    };
  }

  static double? _rounded(double? coordinate) =>
      coordinate == null ? null : CoordinatePrecision.round6(coordinate);

  /// Atamanın mesai oturumları, girişten çıkışa.
  ///
  /// İki taraf da okuyabiliyor; işveren tarafı da bu metodu çağırıyor
  /// (`b_job_detail_page`), tıpkı sohbette olduğu gibi tek servis iki
  /// uygulamaya hizmet ediyor.
  Future<List<WorkSession>> fetchWorkSessions(String assignmentId) {
    return _apiClient.get<List<WorkSession>>(
      ApiPaths.assignmentWorkSessions(assignmentId),
      parse: (data) => data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(WorkSession.fromJson)
                .toList()
          : const [],
    );
  }

  /// Atamayı iptal eder ve oluşan iptal kaydını döndürür.
  ///
  /// İki taraf da çağırabiliyor, ama sonucu aynı değil: çalışan iptal ederse
  /// kesinti yok, işveren iptal ederse işin başlamasına kalan süreye göre
  /// kesinti uygulanabiliyor. Tutarı önden öğrenmek için
  /// [fetchCancellationPreview] var; sunucu iptalde yeniden hesaplıyor.
  ///
  /// [reason] zorunlu; sunucu boş gerekçeyi `400` ile reddediyor.
  /// `PENDING_CONFIRMATION`, `CONFIRMED` ve `IN_PROGRESS` dışından ya da
  /// ikinci kez çağrılırsa `409`.
  Future<Cancellation> cancel({
    required String assignmentId,
    required String reason,
  }) {
    return _apiClient.post<Cancellation>(
      ApiPaths.cancelAssignment(assignmentId),
      body: {'reason': reason},
      parse: (data) => Cancellation.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// İptal edilse ne kesileceğini, iptal etmeden döndürür.
  ///
  /// Hiçbir kayıt oluşturmuyor; iptal kutusu açılırken çağrılıyor. Hesap
  /// **çağıranın kendi tarafına** göre yapılıyor: çalışanda kesinti çıkmıyor,
  /// işverende işin başlamasına kalan süreye göre çıkabiliyor.
  ///
  /// Atama iptale kapalıysa hata değil `cancellableNow: false` dönüyor.
  /// Taraf olmayan `404` alıyor.
  Future<CancellationPreview> fetchCancellationPreview(String assignmentId) {
    return _apiClient.get<CancellationPreview>(
      ApiPaths.assignmentCancellationPreview(assignmentId),
      parse: (data) =>
          CancellationPreview.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Atamanın iptal kaydı; iptal edilmemişse `null`.
  Future<Cancellation?> fetchCancellation(String assignmentId) {
    return _apiClient.get<Cancellation?>(
      ApiPaths.assignmentCancellation(assignmentId),
      parse: (data) =>
          data is Map<String, dynamic> ? Cancellation.fromJson(data) : null,
    );
  }

  /// Uyuşmazlık açar.
  ///
  /// Yalnızca para emanetteyken açılabiliyor; açık uyuşmazlık emanetteki
  /// parayı donduruyor, çalışana ödeme yapılmıyor ve sunucunun kendiliğinden
  /// tamamlaması duruyor. [reason] zorunlu, en fazla 2000 karakter.
  ///
  /// Emanette para yoksa ya da zaten açık bir uyuşmazlık varsa `409`.
  Future<Dispute> openDispute({
    required String assignmentId,
    required String reason,
  }) {
    return _apiClient.post<Dispute>(
      ApiPaths.assignmentDisputes(assignmentId),
      body: {'reason': reason},
      parse: (data) => Dispute.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Atamanın uyuşmazlıkları, açığı da kapanmışı da.
  Future<List<Dispute>> fetchDisputes(String assignmentId) {
    return _apiClient.get<List<Dispute>>(
      ApiPaths.assignmentDisputes(assignmentId),
      parse: (data) => data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(Dispute.fromJson)
                .toList()
          : const [],
    );
  }

  /// Atamayı kabul eder ya da reddeder ve atamanın yeni durumunu döndürür.
  ///
  /// İşveren başvuruyu kabul ettiğinde atama `PENDING_CONFIRMATION`'da
  /// açılıyor; iş, çalışan buraya cevap verene kadar başlamıyor. Cevap
  /// bir kez veriliyor: atama bu durumdan çıkmışsa sunucu `409`, kullanıcı
  /// atamanın tarafı değilse `404` döndürüyor.
  ///
  /// Yanıt `MyAssignmentDto` değil `JobAssignmentDto` — ödeme ve ücret
  /// alanlarını taşımıyor. Bu yüzden yalnızca durum okunuyor, listedeki
  /// kayıt cevaptan değil yeniden çekmeyle tazeleniyor.
  Future<AssignmentStatus> respond({
    required String assignmentId,
    required bool accepted,
  }) {
    return _apiClient.post<AssignmentStatus>(
      ApiPaths.respondToAssignment(assignmentId),
      body: {'accepted': accepted},
      parse: (data) =>
          AssignmentStatus.fromCode((data as Map<String, dynamic>?)?['status']),
    );
  }
}
