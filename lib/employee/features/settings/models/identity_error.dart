/// Sunucunun kimlik doğrulamada döndürdüğü `IDENTITY_*` hataları.
///
/// Sunucunun kendi mesajı Türkçe geliyor ama **ne olduğunu** anlatıyor,
/// **ne yapılacağını** değil: "Kimlik kartının imzası doğrulanamadı" okuyan
/// kullanıcı aynı kartı aynı şekilde tekrar okutuyor. Buradaki karşılıklar
/// bir sonraki adımı söylüyor.
///
/// Kodlar sunucuda mesaj anahtarından türüyor (`{identity.sod.unreadable}`
/// → `IDENTITY_SOD_UNREADABLE`, `KoalaException.deriveErrorCode`), o yüzden
/// mesaj metnine değil **koda** bakılıyor.
enum IdentityError {
  /// Bayrak açık ve `sod` + `dg1` gelmemiş. Bugün olmaması gerekiyor;
  /// olursa kullanıcının çıkış yolu çip okumayı tamamlamak.
  evidenceRequired(
    code: 'IDENTITY_EVIDENCE_REQUIRED',
    message:
        'Doğrulama için kimlik kartının çipini okutman gerekiyor. Kartını '
        'telefonun arkasına yaslayıp taramayı tamamla.',
    retryFromChip: true,
  ),

  /// Sunucudaki CSCA kök sertifika deposu hazır değil. Kullanıcının
  /// yapabileceği bir şey yok; sonra denemesi gerekiyor.
  noTrustAnchors(
    code: 'IDENTITY_NO_TRUST_ANCHORS',
    message:
        'Doğrulama altyapımızda geçici bir sorun var. Kartında bir sorun '
        'yok; birazdan tekrar dene.',
    retryFromChip: false,
  ),

  /// SOD çözümlenemedi: okuma yarım kalmış ya da bozulmuş olabilir.
  sodUnreadable(
    code: 'IDENTITY_SOD_UNREADABLE',
    message:
        'Karttan okunan güvenlik verisi çözülemedi. Kartı telefonun arkasına '
        'yaslayıp okuma bitene kadar hareket ettirmeden tekrar oku.',
    retryFromChip: true,
  ),

  /// İmza doğrulanamadı.
  signatureInvalid(
    code: 'IDENTITY_SIGNATURE_INVALID',
    message:
        'Kartın imzası doğrulanamadı. Okumayı tekrarla; sorun sürerse '
        'destek ekibimizle iletişime geç.',
    retryFromChip: true,
  ),

  /// Kartı imzalayan makam tanınmıyor. Tekrar okumak durumu değiştirmez.
  untrustedDocumentSigner(
    code: 'IDENTITY_UNTRUSTED_DOCUMENT_SIGNER',
    message:
        'Bu kartı imzalayan makamı tanıyamadık. Türkiye Cumhuriyeti kimlik '
        'kartını kullandığından emin ol; kullanıyorsan destek ekibimizle '
        'iletişime geç.',
    retryFromChip: false,
  ),

  /// Veri grubu özetleri imzayla tutmuyor.
  dataGroupTampered(
    code: 'IDENTITY_DATA_GROUP_TAMPERED',
    message:
        'Karttan okunan veri imzasıyla uyuşmadı. Okuma yarıda kalmış '
        'olabilir; kartı yeniden okut.',
    retryFromChip: true,
  ),

  /// Çipteki MRZ çözümlenemedi.
  mrzUnreadable(
    code: 'IDENTITY_MRZ_UNREADABLE',
    message:
        'Kartın makine okunabilir alanı çözümlenemedi. Kartı yeniden okut.',
    retryFromChip: true,
  ),

  /// Beyan edilen TCKN çipteki numarayla tutmuyor.
  numberMismatch(
    code: 'IDENTITY_NUMBER_MISMATCH',
    message:
        'Girdiğin TC kimlik numarası kartın çipindekiyle aynı değil. '
        'Numarayı kartındaki gibi düzeltip tekrar gönder.',
    retryFromChip: false,
  ),

  /// Beyan edilen doğum tarihi çiptekiyle tutmuyor.
  birthDateMismatch(
    code: 'IDENTITY_BIRTH_DATE_MISMATCH',
    message:
        'Girdiğin doğum tarihi kartın çipindekiyle aynı değil. Tarihi '
        'kartındaki gibi düzeltip tekrar gönder.',
    retryFromChip: false,
  ),

  /// Beyan edilen ad soyad çiptekiyle tutmuyor.
  nameMismatch(
    code: 'IDENTITY_NAME_MISMATCH',
    message:
        'Girdiğin ad ve soyad kartın çipindekiyle aynı değil. Kartındaki '
        'yazımla birebir aynı olacak şekilde düzeltip tekrar gönder.',
    retryFromChip: false,
  ),

  /// Çip varlığı kanıtlanamadı.
  chipNotPresent(
    code: 'IDENTITY_CHIP_NOT_PRESENT',
    message:
        'Kartın çipi doğrulanamadı. Kartı telefonun arka üst kısmına yaslayıp '
        'okuma bitene kadar hareket ettirmeden yeniden okut.',
    retryFromChip: true,
  ),

  /// Çipin açık anahtarı (DG15) okunamadı.
  chipKeyUnreadable(
    code: 'IDENTITY_CHIP_KEY_UNREADABLE',
    message:
        'Kartın doğrulama anahtarı okunamadı. Kartı yeniden okut; sorun '
        'sürerse destek ekibimizle iletişime geç.',
    retryFromChip: true,
  ),

  /// Tek kullanımlık sayı tükenmiş ya da süresi dolmuş. **Yeni bir
  /// challenge alıp okumayı baştan yapmak gerekiyor**; eski okumayı tekrar
  /// göndermek aynı hatayı verir.
  challengeInvalid(
    code: 'IDENTITY_CHALLENGE_INVALID',
    message:
        'Doğrulama oturumunun süresi doldu. Kartını baştan okutman '
        'gerekiyor.',
    retryFromChip: true,
    needsFreshChallenge: true,
  ),

  /// Sunucu canlı çip doğrulaması istiyor ama kanıt gelmemiş.
  activeAuthenticationRequired(
    code: 'IDENTITY_ACTIVE_AUTHENTICATION_REQUIRED',
    message:
        'Doğrulama için kartın çipiyle canlı bağlantı gerekiyor. Kartını '
        'telefonun arkasına yaslayıp taramayı tamamla.',
    retryFromChip: true,
  ),

  /// Bu kimlik numarası başka bir hesapta. Tek `409` bu; ayrı tutulması
  /// gerekiyor çünkü çözümü doğrulamayı tekrarlamak değil.
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

  /// Sunucunun `errorCode` alanındaki makine okunur kod.
  final String code;

  /// Kullanıcıya gösterilen, **ne yapacağını** söyleyen metin.
  final String message;

  /// Çipi yeniden okutmak durumu düzeltebilir mi. `false` ise kullanıcıyı
  /// tekrar okutmaya yönlendirmek onu boşuna döngüye sokar.
  final bool retryFromChip;

  /// Yeni bir tek kullanımlık sayı alınmadan tekrar denemek anlamsız mı.
  final bool needsFreshChallenge;

  /// Sunucunun kodundan hatayı bulur; tanımadığı kodda `null` — o zaman
  /// sunucunun kendi mesajı gösteriliyor.
  static IdentityError? fromErrorCode(String? errorCode) {
    if (errorCode == null) return null;

    for (final error in IdentityError.values) {
      if (error.code == errorCode) return error;
    }
    return null;
  }
}
