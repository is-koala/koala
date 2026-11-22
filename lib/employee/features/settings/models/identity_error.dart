/// Kimlik doğrulama `IDENTITY_*` hataları. Sunucunun mesajı ne olduğunu
/// anlatıyor, ne yapılacağını değil; buradaki karşılıklar sonraki adımı
/// söylüyor. Koda bakılıyor.
enum IdentityError {
  /// Bugün olmaması gerekiyor; çıkış yolu çip okumayı tamamlamak.
  evidenceRequired(
    code: 'IDENTITY_EVIDENCE_REQUIRED',
    message:
        'Doğrulama için kimlik kartının çipini okutman gerekiyor. Kartını '
        'telefonun arkasına yaslayıp taramayı tamamla.',
    retryFromChip: true,
  ),

  /// CSCA deposu hazır değil; kullanıcı ancak sonra deneyebilir.
  noTrustAnchors(
    code: 'IDENTITY_NO_TRUST_ANCHORS',
    message:
        'Doğrulama altyapımızda geçici bir sorun var. Kartında bir sorun '
        'yok; birazdan tekrar dene.',
    retryFromChip: false,
  ),

  sodUnreadable(
    code: 'IDENTITY_SOD_UNREADABLE',
    message:
        'Karttan okunan güvenlik verisi çözülemedi. Kartı telefonun arkasına '
        'yaslayıp okuma bitene kadar hareket ettirmeden tekrar oku.',
    retryFromChip: true,
  ),

  signatureInvalid(
    code: 'IDENTITY_SIGNATURE_INVALID',
    message:
        'Kartın imzası doğrulanamadı. Okumayı tekrarla; sorun sürerse '
        'destek ekibimizle iletişime geç.',
    retryFromChip: true,
  ),

  /// Tekrar okumak durumu değiştirmez.
  untrustedDocumentSigner(
    code: 'IDENTITY_UNTRUSTED_DOCUMENT_SIGNER',
    message:
        'Bu kartı imzalayan makamı tanıyamadık. Türkiye Cumhuriyeti kimlik '
        'kartını kullandığından emin ol; kullanıyorsan destek ekibimizle '
        'iletişime geç.',
    retryFromChip: false,
  ),

  dataGroupTampered(
    code: 'IDENTITY_DATA_GROUP_TAMPERED',
    message:
        'Karttan okunan veri imzasıyla uyuşmadı. Okuma yarıda kalmış '
        'olabilir; kartı yeniden okut.',
    retryFromChip: true,
  ),

  mrzUnreadable(
    code: 'IDENTITY_MRZ_UNREADABLE',
    message:
        'Kartın makine okunabilir alanı çözümlenemedi. Kartı yeniden okut.',
    retryFromChip: true,
  ),

  numberMismatch(
    code: 'IDENTITY_NUMBER_MISMATCH',
    message:
        'Girdiğin TC kimlik numarası kartın çipindekiyle aynı değil. '
        'Numarayı kartındaki gibi düzeltip tekrar gönder.',
    retryFromChip: false,
  ),

  birthDateMismatch(
    code: 'IDENTITY_BIRTH_DATE_MISMATCH',
    message:
        'Girdiğin doğum tarihi kartın çipindekiyle aynı değil. Tarihi '
        'kartındaki gibi düzeltip tekrar gönder.',
    retryFromChip: false,
  ),

  nameMismatch(
    code: 'IDENTITY_NAME_MISMATCH',
    message:
        'Girdiğin ad ve soyad kartın çipindekiyle aynı değil. Kartındaki '
        'yazımla birebir aynı olacak şekilde düzeltip tekrar gönder.',
    retryFromChip: false,
  ),

  chipNotPresent(
    code: 'IDENTITY_CHIP_NOT_PRESENT',
    message:
        'Kartın çipi doğrulanamadı. Kartı telefonun arka üst kısmına yaslayıp '
        'okuma bitene kadar hareket ettirmeden yeniden okut.',
    retryFromChip: true,
  ),

  chipKeyUnreadable(
    code: 'IDENTITY_CHIP_KEY_UNREADABLE',
    message:
        'Kartın doğrulama anahtarı okunamadı. Kartı yeniden okut; sorun '
        'sürerse destek ekibimizle iletişime geç.',
    retryFromChip: true,
  ),

  /// DG15 SOD imzasında yok; doğrulanmamış anahtar kabul edilmez.
  chipKeyUnsigned(
    code: 'IDENTITY_CHIP_KEY_UNSIGNED',
    message:
        'Karttan okunan doğrulama anahtarı güvenlik imzasıyla doğrulanamadı. '
        'Doğrulama tamamlanmadı; kartını yeniden okut. Sorun sürerse destek '
        'ekibimizle iletişime geç.',
    retryFromChip: true,
  ),

  /// Sayı tükenmiş ya da süresi dolmuş: **yeni challenge alıp baştan okumak**
  /// gerekir.
  challengeInvalid(
    code: 'IDENTITY_CHALLENGE_INVALID',
    message:
        'Doğrulama oturumunun süresi doldu. Kartını baştan okutman '
        'gerekiyor.',
    retryFromChip: true,
    needsFreshChallenge: true,
  ),

  activeAuthenticationRequired(
    code: 'IDENTITY_ACTIVE_AUTHENTICATION_REQUIRED',
    message:
        'Doğrulama için kartın çipiyle canlı bağlantı gerekiyor. Kartını '
        'telefonun arkasına yaslayıp taramayı tamamla.',
    retryFromChip: true,
  ),

  /// Tek `409`; çözümü doğrulamayı tekrarlamak değil.
  numberAlreadyInUse(
    code: 'TC_IDENTITY_NUMBER_ALREADY_IN_USE',
    message:
        'Bu kimlik numarası başka bir hesapta kayıtlı. Kendi hesabın olduğunu '
        'düşünüyorsan destek ekibimizle iletişime geç.',
    retryFromChip: false,
  );

  const IdentityError({
    required this.code,
    required this.message,
    required this.retryFromChip,
    this.needsFreshChallenge = false,
  });

  final String code;

  final String message;

  /// `false` ise yeniden okutmak boşuna döngüdür.
  final bool retryFromChip;

  final bool needsFreshChallenge;

  /// Tanımadığı kodda `null`; o zaman sunucunun mesajı gösterilir.
  static IdentityError? fromErrorCode(String? errorCode) {
    if (errorCode == null) return null;

    for (final error in IdentityError.values) {
      if (error.code == errorCode) return error;
    }
    return null;
  }
}
