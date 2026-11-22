enum IdentityReviewStatus {
  /// Bu durumda yeni yükleme kabul edilmiyor.
  pending('PENDING'),

  approved('APPROVED'),

  /// Gerekçe [IdentityReview.rejectionReason]'da; yeniden gönderilebilir.
  rejected('REJECTED');

  const IdentityReviewStatus(this.code);

  final String code;

  /// Tanımadığı değerde `null`. `PENDING_REVIEW` da bekliyor sayılıyor.
  static IdentityReviewStatus? fromCode(Object? value) {
    if (value is! String) return null;
    if (value == 'PENDING_REVIEW') return IdentityReviewStatus.pending;
    for (final status in IdentityReviewStatus.values) {
      if (status.code == value) return status;
    }
    return null;
  }
}

/// Oturum sahibinin **son** incelemesi. TCKN yanıtta geliyor ama alınmıyor:
/// ekranın ihtiyacı yok, gereksiz kopya onu log satırına yaklaştırır.
class IdentityReview {
  const IdentityReview({
    required this.id,
    required this.status,
    this.rejectionReason,
    this.createdAt,
    this.rejectedAt,
    this.verifiedAt,
  });

  final String id;
  final IdentityReviewStatus status;

  /// Yalnız reddedilende dolu; boş dize `null`.
  final String? rejectionReason;

  final DateTime? createdAt;

  final DateTime? rejectedAt;

  final DateTime? verifiedAt;

  bool get isPending => status == IdentityReviewStatus.pending;

  bool get isApproved => status == IdentityReviewStatus.approved;

  bool get isRejected => status == IdentityReviewStatus.rejected;

  /// Durum tanınmıyorsa `null`: ekran "inceleme yok" gibi davranır, bilinmeyen
  /// durum için kilitlenmez.
  static IdentityReview? fromJson(Map<String, dynamic> json) {
    final status = IdentityReviewStatus.fromCode(json['status']);
    if (status == null) return null;

    final reason = (json['rejectionReason'] as String?)?.trim();

    return IdentityReview(
      id: json['id'] as String? ?? '',
      status: status,
      rejectionReason: reason == null || reason.isEmpty ? null : reason,
      createdAt: _date(json['createdAt']),
      rejectedAt: _date(json['rejectedAt']),
      verifiedAt: _date(json['verifiedAt']),
    );
  }

  static DateTime? _date(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}

/// Kimlik durumu: `/users/me` bayrağı ile son incelemenin birleşimi. Bayrak
/// yalnız doğrulandı/doğrulanmadı diyor; inceleme doğrulanmamışın **neden**
/// öyle olduğunu.
enum IdentityStatus {
  /// İnceleme olsun olmasın son söz bu.
  verified('Kimlik doğrulandı'),

  pending('Kimlik incelemede'),

  rejected('Kimlik reddedildi'),

  unverified('Kimlik doğrulanmadı');

  const IdentityStatus(this.label);

  final String label;

  /// Onaylanmış inceleme bayrağı beklemiyor: `/users/me` kopyası tazelenene
  /// kadar eski kalabilir.
  static IdentityStatus resolve({
    required bool identityVerified,
    required IdentityReview? review,
  }) {
    if (identityVerified) return IdentityStatus.verified;
    return switch (review?.status) {
      IdentityReviewStatus.approved => IdentityStatus.verified,
      IdentityReviewStatus.pending => IdentityStatus.pending,
      IdentityReviewStatus.rejected => IdentityStatus.rejected,
      null => IdentityStatus.unverified,
    };
  }
}
