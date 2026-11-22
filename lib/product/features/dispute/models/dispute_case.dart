import 'package:koala/employee/features/jobs/models/dispute.dart';
import 'package:koala/product/features/dispute/models/dispute_evidence.dart';
import 'package:koala/product/features/dispute/models/evidence_file.dart';
import 'package:koala/product/models/upload_progress.dart';

/// Uyuşmazlık ve kanıtları. Kanıtlar ayrı isteniyor ve ayrı düşebiliyor: o
/// zaman "kanıt yok" değil "kanıtlar alınamadı" denir ve sayı bilinmediği için
/// ekleme kapalı.
class DisputeCase {
  const DisputeCase({
    required this.dispute,
    this.evidence = const [],
    this.isEvidenceLoading = true,
    this.evidenceError,
  });

  final Dispute dispute;
  final List<DisputeEvidence> evidence;

  final bool isEvidenceLoading;

  /// Elde eski liste varsa o korunur.
  final String? evidenceError;

  bool get isEvidenceKnown => !isEvidenceLoading && evidenceError == null;

  bool get canAttach =>
      isEvidenceKnown &&
      DisputeEvidencePolicy.canAttach(
        isOpen: dispute.isOpen,
        count: evidence.length,
      );

  /// Sınır doldu ama uyuşmazlık açık: ekran nedenini söylüyor.
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

  /// Gövde boyutu bilinmiyorsa `null` (belirsiz çubuk).
  double? get fraction => uploadFraction(sent, total);

  EvidenceUpload withProgress(int sent, int total) => EvidenceUpload(
    disputeId: disputeId,
    fileName: fileName,
    sent: sent,
    total: total,
  );
}
