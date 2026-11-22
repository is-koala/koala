import 'package:flutter/foundation.dart';
import 'package:koala/business/features/home/models/received_application.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// İlanlar arası gelen kutusu. Kapsamı sunucu kuruyor (bireyselde ilanı açan,
/// şirkette **güncel** yetkili); istemci süzmüyor.
class ReceivedApplicationService {
  ReceivedApplicationService._(this._apiClient);

  static final ReceivedApplicationService _instance =
      ReceivedApplicationService._(ApiClient());

  factory ReceivedApplicationService() => _instance;

  @visibleForTesting
  factory ReceivedApplicationService.withClient(ApiClient apiClient) {
    return ReceivedApplicationService._(apiClient);
  }

  /// Sunucunun varsayılanıyla aynı; ayrışırsa sayfa sınırı kayar.
  static const int defaultPageSize = 20;

  static const int maxPageSize = 100;

  final ApiClient _apiClient;

  /// Gelen başvurular. **`sort` gönderilmiyor**: sunucunun "bekleyen önce"
  /// sırası bir `Sort` ile ifade edilemiyor. [status] `unknown` olamaz (`400`);
  /// kapsam dışı kimlik boş sayfa döner.
  Future<ReceivedApplicationPage> fetchReceivedApplications({
    ApplicationStatus? status,
    String? jobId,
    String? companyId,
    int page = 0,
    int size = defaultPageSize,
  }) {
    assert(
      status != ApplicationStatus.unknown,
      'Sunucu bilinmeyen durumu 400 ile reddeder',
    );

    return _apiClient.get<ReceivedApplicationPage>(
      ApiPaths.receivedApplications,
      queryParameters: {
        'status': ?status?.code,
        'jobId': ?jobId,
        'companyId': ?companyId,
        'page': page,
        'size': size,
      },
      parse: (data) =>
          ReceivedApplicationPage.fromJson(data! as Map<String, dynamic>),
    );
  }
}
