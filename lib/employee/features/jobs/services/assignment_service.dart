import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Atama uçları.
///
/// Başvuru kabul edilene kadar iş bir `JobApplication`; kabul edildikten
/// sonrası bir atama ve buradan yönetiliyor. Başvurunun kendisi
/// `JobApplicationService`'te kalıyor — backend'in ikisini ayırdığı yer orası.
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
