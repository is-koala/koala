/// Çip okumanın cihazda **neden** yürümediği. "Kart hareket etti" ile "NFC yok"
/// ayrı: birinde tekrar denemek işe yarar, ötekinde yaramaz ([canRetry]).
/// Sunucu hataları [IdentityError]'da.
enum ChipReadFailure {
  /// Çıkış yolu fotoğraflı inceleme.
  nfcUnsupported(
    title: 'Bu telefon kimlik kartı okuyamıyor',
    message:
        'Telefonunda NFC bulunmuyor, bu yüzden kimlik kartının çipini '
        'okuyamıyoruz. Kimliğini dört fotoğrafla incelemeye göndererek '
        'devam edebilirsin.',
    canRetry: false,
  ),

  /// Android'de ayarlardan açılabilir; iOS'ta NFC kapatılamaz.
  nfcDisabled(
    title: 'NFC kapalı',
    message:
        'Kimlik kartını okuyabilmemiz için telefonunun ayarlarından NFC\'yi '
        'açman gerekiyor. Açtıktan sonra tekrar dene.',
    canRetry: true,
  ),

  /// Elle giriş yolu açık kalır.
  cameraDenied(
    title: 'Kamera izni gerekiyor',
    message:
        'Kartın arka yüzündeki bilgileri okuyabilmemiz için kamera izni '
        'gerekiyor. İzin vermek istemiyorsan bilgileri elle girebilirsin.',
    canRetry: true,
  ),

  ocrModelUnavailable(
    title: 'Metin tanıma modeli hazırlanamadı',
    message:
        'İnternet bağlantını kontrol edip tekrar dene. Android cihazlarda '
        'Google Play Hizmetleri kullanılabilir olmalı. İstersen kimlik '
        'bilgilerini elle girebilirsin.',
    canRetry: true,
  ),

  ocrTimedOut(
    title: 'Metin tanıma tamamlanamadı',
    message:
        'Kartın arka yüzünü işlerken beklenenden uzun sürdü. Tekrar dene; '
        'sorun devam ederse kimlik bilgilerini elle girebilirsin.',
    canRetry: true,
  ),

  /// Boş OCR sonucu henüz inmemiş modelden de okunamayan görüntüden de
  /// gelebilir; eklenti ayırt etmediği için ikisi de anlatılır.
  ocrUnavailableOrUnreadable(
    title: 'Kartın arka yüzü henüz okunamadı',
    message:
        'İlk taramada metin tanıma bileşeni hâlâ hazırlanıyor olabilir. '
        'İnternet bağlantını açık tutup tekrar dene; Android cihazlarda '
        'Google Play Hizmetleri kullanılabilir olmalı. Ayrıca kartı düz bir '
        'zemine koyup alt kısmındaki üç satırın tamamını kadraja alabilirsin.',
    canRetry: true,
  ),

  mrzUnreadable(
    title: 'Kartın arka yüzü okunamadı',
    message:
        'Kartın arka yüzündeki makine okunabilir alanı seçemedik. Kartı düz '
        'bir zemine koy, parlama olmayacak şekilde ışığı ayarla ve alt '
        'kısmındaki üç satırın tamamı kadraja girsin.',
    canRetry: true,
  ),

  cardMoved(
    title: 'Kart okunamadı',
    message:
        'Kartla telefon arasındaki bağlantı koptu. Kartı telefonun arka üst '
        'kısmına yasla ve okuma bitene kadar hareket ettirme.',
    canRetry: true,
  ),

  /// MRZ'den okunan üç alandan biri karttakiyle tutmuyor.
  wrongKey(
    title: 'Kart bilgileri eşleşmedi',
    message:
        'Belge numarası, doğum tarihi ya da son geçerlilik tarihi kartın '
        'çipiyle eşleşmedi. Bilgileri kontrol edip tekrar dene.',
    canRetry: true,
  ),

  /// Eski model kimlik, çipsiz kart ya da başka bir etiket.
  chipUnsupported(
    title: 'Bu kartın çipi okunamıyor',
    message:
        'Okuttuğun kartta çip doğrulamasının beklediği uygulama yok. Çipli '
        'yeni tip kimlik kartını kullandığından emin ol.',
    canRetry: true,
  ),

  /// DG1 beklenen TD1 biçiminde değil; sunucu `MRZ_UNREADABLE` diyecekti.
  holderUnreadable(
    title: 'Kart bilgileri çözümlenemedi',
    message:
        'Kartın çipindeki kimlik bilgileri beklenen biçimde değil. Çipli '
        'yeni tip kimlik kartını kullandığından emin olup tekrar dene; '
        'olmazsa bilgileri elle girebilirsin.',
    canRetry: true,
  ),

  challengeUnavailable(
    title: 'Doğrulama başlatılamadı',
    message:
        'Doğrulama oturumu açılamadı. İnternet bağlantını kontrol edip '
        'tekrar dene.',
    canRetry: true,
  ),

  unknown(
    title: 'Kart okunamadı',
    message:
        'Kimlik kartı okunurken beklenmeyen bir sorun oldu. Kartı telefonun '
        'arkasına yaslayıp tekrar dene.',
    canRetry: true,
  );

  const ChipReadFailure({
    required this.title,
    required this.message,
    required this.canRetry,
  });

  final String title;

  /// **Ne yapılacağı.**
  final String message;

  final bool canRetry;
}

/// Çip okumanın tek hata tipi; durum [reason]'da.
class ChipReadException implements Exception {
  const ChipReadException(this.reason, {this.cause});

  final ChipReadFailure reason;

  /// Gösterilmiyor; teşhis için taşınıyor.
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'ChipReadException(${reason.name})'
      : 'ChipReadException(${reason.name}) (cause: $cause)';
}
