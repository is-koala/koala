import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/jobs/models/dispute.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';
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

/// Bir uyuşmazlık ve onun kanıtları.
///
/// Kanıtlar uyuşmazlıktan **ayrı** isteniyor ve ayrı başarısız olabiliyor:
/// liste gelmiş, kanıtlar gelmemiş bir uyuşmazlık "kanıt yok" demiyor,
/// "kanıtlar alınamadı" diyor ve yeni dosya eklemeye izin vermiyor (sayı
/// bilinmiyor).
class DisputeCase {
  const DisputeCase({
    required this.dispute,
    this.evidence = const [],
    this.isEvidenceLoading = true,
    this.evidenceError,
  });

  final Dispute dispute;
  final List<DisputeEvidence> evidence;

  /// Kanıt listesi isteği sürüyor ve elde gösterilecek bir liste yok.
  final bool isEvidenceLoading;

  /// Kanıt listesinin hata mesajı; elde eski liste varsa o korunur.
  final String? evidenceError;

  /// Sayının bilindiği hâl: yüklenmiş ve hatasız.
  bool get isEvidenceKnown => !isEvidenceLoading && evidenceError == null;

  /// Bu uyuşmazlığa şimdi kanıt eklenebilir mi ([DisputeEvidencePolicy]).
  bool get canAttach =>
      isEvidenceKnown &&
      DisputeEvidencePolicy.canAttach(
        isOpen: dispute.isOpen,
        count: evidence.length,
      );

  /// Sınır doldu ama uyuşmazlık hâlâ açık: ekran nedenini söylüyor.
  bool get isLimitReached =>
      dispute.isOpen &&
      isEvidenceKnown &&
      evidence.length >= DisputeEvidencePolicy.maxPerDispute;

  DisputeCase copyWith({
    Dispute? dispute,
    List<DisputeEvidence>? evidence,
    bool? isEvidenceLoading,
    Object? evidenceError = _keep,
  }) {
    return DisputeCase(
      dispute: dispute ?? this.dispute,
      evidence: evidence ?? this.evidence,
      isEvidenceLoading: isEvidenceLoading ?? this.isEvidenceLoading,
      evidenceError: identical(evidenceError, _keep)
          ? this.evidenceError
          : evidenceError as String?,
    );
  }

  static const Object _keep = Object();
}

/// Süren yüklemenin ilerlemesi.
class EvidenceUpload {
  const EvidenceUpload({
    required this.disputeId,
    required this.fileName,
    this.sent = 0,
    this.total = 0,
  });

  final String disputeId;
  final String fileName;
  final int sent;
  final int total;

  /// 0-1 arası oran; gövde boyutu henüz bilinmiyorsa `null` (belirsiz çubuk).
  double? get fraction => total <= 0 ? null : (sent / total).clamp(0.0, 1.0);

  EvidenceUpload withProgress(int sent, int total) => EvidenceUpload(
    disputeId: disputeId,
    fileName: fileName,
    sent: sent,
    total: total,
  );
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
  }) : _assignments = assignmentService ?? AssignmentService(),
       _evidence = evidenceService ?? DisputeEvidenceService();

  final String assignmentId;
  final AssignmentService _assignments;
  final DisputeEvidenceService _evidence;

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
        for (final dispute in _sorted(disputes))
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

  /// Yeni olan önde; tarihi olmayan en sona. Eşitlikte sunucu sırası korunur.
  static List<Dispute> _sorted(List<Dispute> disputes) {
    final indexed = [
      for (var i = 0; i < disputes.length; i++)
        (index: i, dispute: disputes[i]),
    ];
    indexed.sort((a, b) {
      final left = a.dispute.createdAt;
      final right = b.dispute.createdAt;
      if (left == null && right == null) return a.index.compareTo(b.index);
      if (left == null) return 1;
      if (right == null) return -1;
      final byDate = right.compareTo(left);
      return byDate != 0 ? byDate : a.index.compareTo(b.index);
    });
    return [for (final entry in indexed) entry.dispute];
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

    final accepted = DisputeEvidencePolicy.accept(candidate);
    final file = accepted.file;
    if (file == null) return AttachResult.rejected(accepted.rejection!);

    final generation = _generation;
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
      _upload = null;
      _notify();
      // Aynı anda başlamış eski bir okuma yeni dosyayı silmesin: sunucudaki
      // liste yeniden okunuyor (kendi nesliyle, eskisini geçersiz kılar).
      await _readEvidence(disputeId, generation: generation);
      return AttachResult.attached(evidence);
    } on ApiException catch (error) {
      final failure = DisputeEvidenceFailure.from(error);
      if (_disposed) return AttachResult.failed(failure);
      _upload = null;
      _notify();
      if (failure.action == DisputeEvidenceAction.reload) {
        await _read(keepCases: true);
      }
      return AttachResult.failed(failure);
    }
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
