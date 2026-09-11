import 'package:flutter/foundation.dart';
import 'package:koala/business/features/home/models/talent_pool_entry.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// İşverenin yetenek havuzu.
///
/// Havuz kullanıcı bazlıdır; bu dilim [companyId] göndermez. Gönderilirse
/// gövdeye yalnızca dolu olduğunda girer — sunucu bir kez yazılan şirketi
/// temizlemez.
class TalentPoolService {
  TalentPoolService._(this._apiClient);

  static final TalentPoolService _instance = TalentPoolService._(ApiClient());

  factory TalentPoolService() => _instance;

  @visibleForTesting
  factory TalentPoolService.withClient(ApiClient apiClient) {
    return TalentPoolService._(apiClient);
  }

  /// Sunucunun not üst sınırı (`SaveTalentPoolEntryDto`).
  static const int maxNoteLength = 1000;

  /// Varsayılan sayfa boyutu; sunucunun kendi varsayılanıyla aynı.
  static const int defaultPageSize = 20;

  final ApiClient _apiClient;

  /// Oturum sahibinin havuzu, yeniden eskiye (`createdAt,desc`).
  ///
  /// `sort` gönderilmiyor: sunucu yalnız `createdAt` kabul ediyor, başka bir
  /// alan `400`.
  Future<TalentPoolPage> fetchTalentPool({
    int page = 0,
    int size = defaultPageSize,
  }) {
    return _apiClient.get<TalentPoolPage>(
      ApiPaths.currentUserTalentPool,
      queryParameters: {'page': page, 'size': size},
      parse: (data) => TalentPoolPage.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// İşçiyi havuza ekler ya da var olan kaydın notunu günceller.
  ///
  /// Gövdesiz `PUT` var olan notu siler. Not verildiyse gövdeye girer;
  /// 1000 karakteri aşan kısım kesilir.
  Future<TalentPoolEntry> addWorker(
    String workerId, {
    String? note,
    String? companyId,
  }) {
    return _apiClient.put<TalentPoolEntry>(
      ApiPaths.currentUserTalentPoolEntry(workerId),
      body: _writeBody(note: note, companyId: companyId),
      parse: (data) => TalentPoolEntry.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// İşçiyi havuzdan çıkarır. Havuzda değilse sunucu sessizce geçer.
  Future<void> removeWorker(String workerId) {
    return _apiClient.deleteWithoutData(
      ApiPaths.currentUserTalentPoolEntry(workerId),
    );
  }

  Map<String, dynamic>? _writeBody({String? note, String? companyId}) {
    if (note == null && companyId == null) return null;

    final clippedNote = note == null ? null : _clipNote(note);
    return {'note': ?clippedNote, 'companyId': ?companyId};
  }

  String _clipNote(String note) {
    if (note.length <= maxNoteLength) return note;
    return note.substring(0, maxNoteLength);
  }
}
