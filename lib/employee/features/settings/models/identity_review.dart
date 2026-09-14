/// Personel incelemesinin durumu. Sunucunun `IdentityReviewStatus`
/// enum'ının karşılığı.
enum IdentityReviewStatus {
  /// Fotoğraflar kuyrukta; personel henüz bakmadı. Bu durumda yeni yükleme
  /// kabul edilmiyor (`IDENTITY_DOCUMENTS_ALREADY_PENDING`).
  pending('PENDING'),

  /// Personel onayladı; `/users/me`'deki `identityVerified` de `true`.
  approved('APPROVED'),

  /// Personel reddetti; gerekçe [IdentityReview.rejectionReason]'da ve
  /// kullanıcı yeni fotoğraflarla tekrar gönderebiliyor.
  rejected('REJECTED');

  const IdentityReviewStatus(this.code);

  /// Sunucudan gelen değer.
  final String code;

  /// Sunucu kodundan durumu bulur; tanımadığı değerde `null`.
  ///
  /// `PENDING_REVIEW` da bekliyor sayılıyor: ürün metinleri durumu bu adla
  /// anıyor ve sunucu bir gün enum'ı o yöne çevirirse uygulama kör kalmasın.
  static IdentityReviewStatus? fromCode(Object? value) {
    if (value is! String) return null;
    if (value == 'PENDING_REVIEW') return IdentityReviewStatus.pending;
    for (final status in IdentityReviewStatus.values) {
      if (status.code == value) return status;
    }
    return null;
  }
}

/// `GET /users/me/identity-documents` yanıtı: oturum sahibinin **son**
/// incelemesi.
///
/// TCKN yanıtta geliyor ama buraya alınmıyor: ekranın ihtiyacı durum,
/// gerekçe ve tarihler; kimlik numarasını gereksiz yere bir modelde daha
/// taşımak onu bir log satırına daha yaklaştırır.
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

  /// Personelin yazdığı red gerekçesi; yalnız [IdentityReviewStatus.rejected]
  /// durumunda dolu. Boş dizge gelirse `null` sayılıyor.
  final String? rejectionReason;

  /// Fotoğrafların gönderildiği an.
  final DateTime? createdAt;

  final DateTime? rejectedAt;

  final DateTime? verifiedAt;

  bool get isPending => status == IdentityReviewStatus.pending;

  bool get isApproved => status == IdentityReviewStatus.approved;

  bool get isRejected => status == IdentityReviewStatus.rejected;

  /// Yanıtı çözer; durum tanınmıyorsa `null` — ekran o zaman "inceleme yok"
  /// gibi davranıp formu çiziyor, bilinmeyen bir durum adına ekranı
  /// kilitlemiyor.
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

/// Kullanıcının kimlik durumu: `/users/me` bayrağı ile son incelemenin
/// birleşimi.
///
/// İkisi ayrı yerden geliyor ve tek başına yetmiyor: bayrak yalnız
/// "doğrulandı / doğrulanmadı" diyor, inceleme ise doğrulanmamış kullanıcının
/// **neden** hâlâ öyle olduğunu — bekliyor mu, reddedildi mi, hiç
/// göndermedi mi. Rozet ve durum ekranı bu dört hâli ayırıyor.
enum IdentityStatus {
  /// `identityVerified == true`. İnceleme kaydı olsun olmasın son söz bu.
  verified('Kimlik doğrulandı'),

  /// Fotoğraflar personel kuyruğunda.
  pending('Kimlik incelemede'),

  /// Son inceleme reddedildi; kullanıcı yeniden yüklemeli.
  rejected('Kimlik reddedildi'),

  /// Ne doğrulama ne bekleyen inceleme var.
  unverified('Kimlik doğrulanmadı');

  const IdentityStatus(this.label);

  /// Rozette görünen metin.
  final String label;

  /// Bayrak ile incelemeden durumu türetir.
  ///
  /// Onaylanmış inceleme bayrağı beklemiyor: personel onayı `identityVerified`
  /// damgasını atıyor ama `/users/me` kopyası tazelenene kadar eski kalabilir;
  /// sunucunun "onaylandı" dediği bir kaydı "doğrulanmadı" diye göstermek
  /// yanlış olurdu.
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
