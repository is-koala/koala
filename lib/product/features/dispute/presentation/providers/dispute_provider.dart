import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/jobs/models/dispute.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';
import 'package:koala/product/features/dispute/models/dispute_case.dart';
import 'package:koala/product/features/dispute/models/dispute_evidence.dart';
import 'package:koala/product/features/dispute/models/dispute_evidence_error.dart';
import 'package:koala/product/features/dispute/models/evidence_file.dart';
import 'package:koala/product/features/dispute/services/dispute_evidence_service.dart';
import 'package:koala/product/network/api_exception.dart';

/// Atamanın uyuşmazlıkları yüklenirken ekranın durumu.
enum DisputeLoad {
  /// İlk okuma sürüyor; liste henüz çizilemez.
  loading,

  /// Uyuşmazlıklar geldi (boş olabilir).
  ready,

  /// Uyuşmazlık listesi okunamadı ve elde eski liste yok.
  failed,
}

/// Bir yükleme isteğinin sonucu: kanıt, ya da neden olmadığı.
class AttachResult {
  const AttachResult._({this.evidence, this.rejection, this.failure});

  /// Yüklendi.
  const AttachResult.attached(DisputeEvidence evidence)
    : this._(evidence: evidence);

  /// Dosya sunucuya gitmeden sınırlardan döndü.
  const AttachResult.rejected(EvidenceRejection rejection)
    : this._(rejection: rejection);

  /// Sunucu reddetti ya da ağ koptu.
  const AttachResult.failed(DisputeEvidenceFailure failure)
    : this._(failure: failure);

  /// Başka bir yükleme sürüyordu; bu istek hiç başlamadı.
  const AttachResult.busy() : this._();

  final DisputeEvidence? evidence;
  final EvidenceRejection? rejection;
  final DisputeEvidenceFailure? failure;

  bool get isAttached => evidence != null;

  /// Kullanıcıya söylenecek cümle; başarıda ve `busy`'de `null`.
  String? get message => rejection?.message ?? failure?.message;
}

/// Bir indirme isteğinin sonucu.
class DownloadResult {
  const DownloadResult._({this.url, this.failure, this.isStreamed = false});

  /// Kısa ömürlü imzalı adres; hemen açılmalı.
  const DownloadResult.signed(Uri url) : this._(url: url);

  /// Sunucu imzalı adres veremedi, baytları kendisi akıtıyor; uygulama içinde
  /// saklanamıyor (yeni bağımlılık gerekir).
  const DownloadResult.streamed() : this._(isStreamed: true);

  const DownloadResult.failed(DisputeEvidenceFailure failure)
    : this._(failure: failure);

  /// Başka bir indirme sürüyordu.
  const DownloadResult.busy() : this._();

  final Uri? url;
  final DisputeEvidenceFailure? failure;
  final bool isStreamed;
}

/// Bir atamanın uyuşmazlıkları ve kanıtları (is-koala/koala#215).
///
/// **Sayfaya ait, uygulama boyunca yaşamıyor** ([BApplicationInboxProvider]
/// ile aynı gerekçe): kanıt listesi iki tarafın adını ve dosya adlarını
/// taşıyor, `main.dart`'ta kayıtlı değil ve çıkışta temizlenecek bir şey
/// bırakmıyor.
///
/// Üç şey sıralanıyor:
/// - her baştan okuma bir **nesil** numarası alıyor; geç dönen eski yanıt ve
///   sayfa kapandıktan sonra dönen yanıt atılıyor;
/// - bir uyuşmazlığın kanıt listesinin kendi numarası var; yükleme bitince
///   liste sunucudan yeniden okunuyor ki aynı anda başlamış eski bir okuma
///   yeni dosyayı silmesin;
/// - aynı anda tek yükleme ve tek indirme.
class DisputeProvider extends ChangeNotifier {
  DisputeProvider({
    required this.assignmentId,
    AssignmentService? assignmentService,
    DisputeEvidenceService? evidenceService,
    DateTime Function()? clock,
  }) : _assignments = assignmentService ?? AssignmentService(),
       _evidence = evidenceService ?? DisputeEvidenceService(),
       _clock = clock ?? DateTime.now;

  final String assignmentId;
  final AssignmentService _assignments;
  final DisputeEvidenceService _evidence;

  /// Yükleme anı; adı olmayan dosya buna göre adlanıyor
  /// ([DisputeEvidencePolicy.generatedBaseName]). Testler sabit saat veriyor.
  final DateTime Function() _clock;

  List<DisputeCase> _cases = const [];
  DisputeLoad _load = DisputeLoad.loading;
  String? _errorMessage;
  bool _isRefreshing = false;
  EvidenceUpload? _upload;
  String? _downloadingId;

  int _generation = 0;
  final Map<String, int> _evidenceGeneration = {};
  bool _disposed = false;

  /// Uyuşmazlıklar, en yeni önde.
  List<DisputeCase> get cases => List.unmodifiable(_cases);

  DisputeLoad get load => _load;

  /// [DisputeLoad.failed] iken ya da başarısız yenilemede sebep.
  String? get errorMessage => _errorMessage;

  bool get isRefreshing => _isRefreshing;

  /// Süren yükleme; yoksa `null`. Bu sırada ikinci bir yükleme başlamıyor.
  EvidenceUpload? get upload => _upload;

  bool get isUploading => _upload != null;

  /// Süren indirmenin kanıt kimliği.
  String? get downloadingId => _downloadingId;

  /// İlk okuma: satırlar düşer, çark çizilir.
  Future<void> start() => _read(keepCases: false);

  /// Çekip yenileme: satırlar yenisi gelene kadar yerinde kalır.
  Future<void> refresh() => _read(keepCases: true);

  Future<void> _read({required bool keepCases}) async {
    final generation = ++_generation;
    _errorMessage = null;
    if (keepCases) {
      _isRefreshing = true;
    } else {
      _isRefreshing = false;
      _load = DisputeLoad.loading;
      _cases = const [];
    }
    _notify();

    try {
      final disputes = await _assignments.fetchDisputes(assignmentId);
      if (generation != _generation) return;

      final previous = {for (final entry in _cases) entry.dispute.id: entry};
      _cases = [
        for (final dispute in Dispute.newestFirst(disputes))
          // Yenilemede eldeki kanıt listesi yeni liste gelene kadar korunuyor:
          // satır çark çizip "kanıt yok" yanıp sönmesin.
          previous[dispute.id]?.copyWith(dispute: dispute) ??
              DisputeCase(dispute: dispute),
      ];
      _load = DisputeLoad.ready;
      _isRefreshing = false;
      _notify();

      await Future.wait([
        for (final entry in _cases)
          _readEvidence(entry.dispute.id, generation: generation),
      ]);
    } on ApiException catch (error) {
      if (generation != _generation) return;
      _errorMessage = error.message;
      _isRefreshing = false;
      // Elde eski liste varsa ekran onu çizmeye devam ediyor.
      if (_cases.isEmpty) _load = DisputeLoad.failed;
      _notify();
    }
  }

  /// Bir uyuşmazlığın kanıtlarını yeniden okur (liste hatasındaki *Tekrar
  /// Dene* ve yükleme sonrası).
  Future<void> reloadEvidence(String disputeId) =>
      _readEvidence(disputeId, generation: _generation);

  Future<void> _readEvidence(
    String disputeId, {
    required int generation,
  }) async {
    final token = (_evidenceGeneration[disputeId] ?? 0) + 1;
    _evidenceGeneration[disputeId] = token;

    // Elde liste yoksa çark; varsa üstünde okunuyor, satırlar kalıyor.
    _updateCase(
      disputeId,
      (entry) => entry.copyWith(
        isEvidenceLoading: entry.evidence.isEmpty,
        evidenceError: null,
      ),
    );

    try {
      final loaded = await _evidence.fetchEvidence(disputeId);
      if (_stale(generation, disputeId, token)) return;
      _updateCase(
        disputeId,
        (entry) => entry.copyWith(
          evidence: loaded,
          isEvidenceLoading: false,
          evidenceError: null,
        ),
      );
    } on ApiException catch (error) {
      if (_stale(generation, disputeId, token)) return;
      _updateCase(
        disputeId,
        (entry) => entry.copyWith(
          isEvidenceLoading: false,
          evidenceError: error.message,
        ),
      );
    }
  }

  bool _stale(int generation, String disputeId, int token) =>
      _disposed ||
      generation != _generation ||
      _evidenceGeneration[disputeId] != token;

  /// Seçilen dosyayı kabul edip yükler.
  ///
  /// Sınırlardan dönerse ([EvidenceRejection]) sunucuya gidilmez. Başarıda kanıt
  /// listeye hemen ekleniyor, ardından liste sunucudan yeniden okunuyor.
  /// Sunucu "durum değişmiş" diyorsa ([DisputeEvidenceAction.reload]:
  /// sonuçlandı, sınır doldu, kayıt yok) uyuşmazlıklar baştan okunuyor — eldeki
  /// düğme bayattı.
  Future<AttachResult> attach(
    String disputeId,
    EvidenceCandidate candidate,
  ) async {
    if (_upload != null) return const AttachResult.busy();

    final accepted = DisputeEvidencePolicy.accept(candidate, now: _clock());
    final file = accepted.file;
    if (file == null) return AttachResult.rejected(accepted.rejection!);

    _upload = EvidenceUpload(disputeId: disputeId, fileName: file.uploadName);
    _notify();

    try {
      final evidence = await _evidence.upload(
        disputeId,
        file,
        onProgress: (sent, total) {
          final current = _upload;
          if (_disposed || current == null || current.disputeId != disputeId) {
            return;
          }
          _upload = current.withProgress(sent, total);
          _notify();
        },
      );
      if (_disposed) return AttachResult.attached(evidence);

      _upload = null;
      _updateCase(
        disputeId,
        (entry) => entry.copyWith(
          evidence: [
            ...entry.evidence.where((item) => item.id != evidence.id),
            evidence,
          ],
          isEvidenceLoading: false,
          evidenceError: null,
        ),
      );
      // Aynı anda başlamış eski bir okuma yeni dosyayı silmesin: sunucudaki
      // liste yeniden okunuyor (kendi nesliyle, eskisini geçersiz kılar).
      // Nesil **şimdiki**: yükleme sürerken bir yenileme başlamışsa onun
      // numarasıyla okumak bu okumayı atılmış sayardı.
      await _readEvidence(disputeId, generation: _generation);
      return AttachResult.attached(evidence);
    } on ApiException catch (error) {
      final failure = DisputeEvidenceFailure.from(error);
      if (_disposed) return AttachResult.failed(failure);
      _clearUpload();
      if (failure.action == DisputeEvidenceAction.reload) {
        await _read(keepCases: true);
      }
      return AttachResult.failed(failure);
    } finally {
      // Beklenmeyen bir hata da ilerleme çubuğunu açık, "Kanıt Ekle"yi kapalı
      // bırakmamalı.
      _clearUpload();
    }
  }

  void _clearUpload() {
    if (_upload == null) return;
    _upload = null;
    _notify();
  }

  /// Kanıtın indirileceği imzalı adresi ister.
  ///
  /// Adres üç dakika geçerli ve `Bearer` olmadan açılıyor; çağıran onu hemen
  /// harici tarayıcıya vermeli ve saklamamalı.
  Future<DownloadResult> download(DisputeEvidence evidence) async {
    if (_downloadingId != null) return const DownloadResult.busy();

    _downloadingId = evidence.id;
    _notify();

    try {
      final url = await _evidence.resolveDownload(
        evidence.disputeId,
        evidence.id,
      );
      return url == null
          ? const DownloadResult.streamed()
          : DownloadResult.signed(url);
    } on ApiException catch (error) {
      final failure = DisputeEvidenceFailure.from(error);
      if (!_disposed && failure.action == DisputeEvidenceAction.reload) {
        await reloadEvidence(evidence.disputeId);
      }
      return DownloadResult.failed(failure);
    } finally {
      _downloadingId = null;
      _notify();
    }
  }

  void _updateCase(
    String disputeId,
    DisputeCase Function(DisputeCase entry) update,
  ) {
    final index = _cases.indexWhere((entry) => entry.dispute.id == disputeId);
    if (index < 0) return;
    _cases = [..._cases]..[index] = update(_cases[index]);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Sayfa kapanırken uçuştaki istekler eskimiş sayılıyor: dönen yanıt atılmış
  /// bir `ChangeNotifier`'a `notifyListeners` demesin.
  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
