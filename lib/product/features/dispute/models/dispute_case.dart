import 'package:koala/employee/features/jobs/models/dispute.dart';
import 'package:koala/product/features/dispute/models/dispute_evidence.dart';
import 'package:koala/product/features/dispute/models/evidence_file.dart';
import 'package:koala/product/models/upload_progress.dart';

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
  double? get fraction => uploadFraction(sent, total);

  EvidenceUpload withProgress(int sent, int total) => EvidenceUpload(
    disputeId: disputeId,
    fileName: fileName,
    sent: sent,
    total: total,
  );
}
