import 'package:flutter/foundation.dart';
import 'package:koala/business/features/home/models/received_application.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// İşverenin ilanlar arası başvuru gelen kutusu.
///
/// Kapsamı sunucu kuruyor: bireysel ilanda ilanı açan, şirket ilanında
/// şirketin **güncel** yetkilisi. Şirket ilanını açıp sonra yetkiden çıkan
/// kullanıcı o ilanın başvurularını görmez; istemcinin ayrıca süzmesi ya da
/// kapsamı genişletmesi gerekmiyor.
class ReceivedApplicationService {
  ReceivedApplicationService._(this._apiClient);

  static final ReceivedApplicationService _instance =
      ReceivedApplicationService._(ApiClient());

  factory ReceivedApplicationService() => _instance;

  @visibleForTesting
  factory ReceivedApplicationService.withClient(ApiClient apiClient) {
    return ReceivedApplicationService._(apiClient);
  }

  /// Sunucunun kendi varsayılanıyla aynı (`PageableDefault(size = 20)`);
  /// üst sınırı 100. Ayrışırsa sayfa sınırı sessizce kayar.
  static const int defaultPageSize = 20;

  /// Sunucunun kabul ettiği en büyük sayfa boyutu (`PageableSanitizer`).
  static const int maxPageSize = 100;

  final ApiClient _apiClient;

  /// Gelen başvurular; [status], [jobId] ve [companyId] boşsa süzgeç yok.
  ///
  /// **`sort` gönderilmiyor.** Sunucunun varsayılan sırası bekleyenleri öne
  /// alıyor, sonra başvuru tarihine göre yeniden eskiye gidiyor; `sort`
  /// verildiğinde bu sıra tümüyle yerini bırakıyor ve "bekleyen önce" bir
  /// `Sort` ile ifade edilemiyor.
  ///
  /// [status] `unknown` olamaz: sunucu bilinmeyen durum değerine `400`
  /// veriyor. Kapsam dışı [jobId] / [companyId] hata değil, boş sayfa.
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
