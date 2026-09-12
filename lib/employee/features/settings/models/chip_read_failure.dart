/// Cihaz tarafında çip okumanın **neden** yürümediği.
///
/// Tek bir "bir hata oluştu" metni bu akışta kullanıcıyı döngüye sokuyor:
/// "kart hareket etti" ile "bu telefonda NFC yok" bambaşka iki durum ve
/// birincisinde tekrar denemek işe yarıyor, ikincisinde asla yaramıyor.
/// Ayrımı [canRetry] taşıyor.
///
/// Sunucunun döndürdüğü hatalar burada değil — onlar [IdentityError]'da.
enum ChipReadFailure {
  /// Telefonda NFC donanımı yok. Tekrar denemenin faydası yok; kullanıcının
  /// çıkış yolu elle doğrulama talebi.
  nfcUnsupported(
    title: 'Bu telefon kimlik kartı okuyamıyor',
    message:
        'Telefonunda NFC bulunmuyor, bu yüzden kimlik kartının çipini '
        'okuyamıyoruz. Kimlik bilgilerini elle girerek devam edebilirsin.',
    canRetry: false,
  ),

  /// NFC var ama kapalı. Android'de kullanıcı ayarlardan açabiliyor;
  /// iOS'ta böyle bir durum yok, NFC kapatılamıyor.
  nfcDisabled(
    title: 'NFC kapalı',
    message:
        'Kimlik kartını okuyabilmemiz için telefonunun ayarlarından NFC\'yi '
        'açman gerekiyor. Açtıktan sonra tekrar dene.',
    canRetry: true,
  ),

  /// Kamera izni verilmedi; MRZ taranamıyor. Elle giriş yolu açık kalıyor.
  cameraDenied(
    title: 'Kamera izni gerekiyor',
    message:
        'Kartın arka yüzündeki bilgileri okuyabilmemiz için kamera izni '
        'gerekiyor. İzin vermek istemiyorsan bilgileri elle girebilirsin.',
    canRetry: true,
  ),

  /// Paketlenmeyen OCR modeli indirilemedi ya da platform çağrısı tamamlanmadı.
  ocrModelUnavailable(
    title: 'Metin tanıma modeli hazırlanamadı',
    message:
        'İnternet bağlantını kontrol edip tekrar dene. Android cihazlarda '
        'Google Play Hizmetleri kullanılabilir olmalı. İstersen kimlik '
        'bilgilerini elle girebilirsin.',
    canRetry: true,
  ),

  /// OCR çağrısı platformdan bağımsız zaman sınırını aştı.
  ocrTimedOut(
    title: 'Metin tanıma tamamlanamadı',
    message:
        'Kartın arka yüzünü işlerken beklenenden uzun sürdü. Tekrar dene; '
        'sorun devam ederse kimlik bilgilerini elle girebilirsin.',
    canRetry: true,
  ),

  /// Boş OCR sonucu ilk kullanımda henüz hazır olmayan indirilebilir modelden
  /// de tamamen okunamayan görüntüden de gelebilir. Eklenti bu iki durumu
  /// ayıran bir sinyal vermediği için kullanıcıya iki olasılık da anlatılır.
  ocrUnavailableOrUnreadable(
    title: 'Kartın arka yüzü henüz okunamadı',
    message:
        'İlk taramada metin tanıma bileşeni hâlâ hazırlanıyor olabilir. '
        'İnternet bağlantını açık tutup tekrar dene; Android cihazlarda '
        'Google Play Hizmetleri kullanılabilir olmalı. Ayrıca kartı düz bir '
        'zemine koyup alt kısmındaki üç satırın tamamını kadraja alabilirsin.',
    canRetry: true,
  ),

  /// OCR MRZ'yi bulamadı ya da kontrol hanesi tutmadı.
  mrzUnreadable(
    title: 'Kartın arka yüzü okunamadı',
    message:
        'Kartın arka yüzündeki makine okunabilir alanı seçemedik. Kartı düz '
        'bir zemine koy, parlama olmayacak şekilde ışığı ayarla ve alt '
        'kısmındaki üç satırın tamamı kadraja girsin.',
    canRetry: true,
  ),

  /// Karta hiç bağlanılamadı ya da okuma ortasında kart uzaklaştı.
  cardMoved(
    title: 'Kart okunamadı',
    message:
        'Kartla telefon arasındaki bağlantı koptu. Kartı telefonun arka üst '
        'kısmına yasla ve okuma bitene kadar hareket ettirme.',
    canRetry: true,
  ),

  /// BAC/PACE oturumu açılamadı: anahtar yanlış, yani MRZ'den okunan üç
  /// alandan biri kartın üzerindekiyle tutmuyor.
  wrongKey(
    title: 'Kart bilgileri eşleşmedi',
    message:
        'Belge numarası, doğum tarihi ya da son geçerlilik tarihi kartın '
        'çipiyle eşleşmedi. Bilgileri kontrol edip tekrar dene.',
    canRetry: true,
  ),

  /// Okunan etiket eMRTD uygulamasını taşımıyor: eski model kimlik, çipsiz
  /// kart ya da bambaşka bir NFC etiketi.
  chipUnsupported(
    title: 'Bu kartın çipi okunamıyor',
    message:
        'Okuttuğun kartta çip doğrulamasının beklediği uygulama yok. Çipli '
        'yeni tip kimlik kartını kullandığından emin ol.',
    canRetry: true,
  ),

  /// Çip açıldı ve okundu ama DG1'deki MRZ kimlik bilgilerini (TCKN, ad,
  /// doğum tarihi, belge no) beklenen TD1 biçiminde taşımıyor. Sunucu aynı
  /// alanları okuyup `MRZ_UNREADABLE` ile reddedecekti; kullanıcıyı boş bir
  /// gidiş dönüşe sokmak yerine okuma burada duruyor.
  holderUnreadable(
    title: 'Kart bilgileri çözümlenemedi',
    message:
        'Kartın çipindeki kimlik bilgileri beklenen biçimde değil. Çipli '
        'yeni tip kimlik kartını kullandığından emin olup tekrar dene; '
        'olmazsa bilgileri elle girebilirsin.',
    canRetry: true,
  ),

  /// Sunucudan tek kullanımlık sayı alınamadı; ağ ya da oturum sorunu.
  challengeUnavailable(
    title: 'Doğrulama başlatılamadı',
    message:
        'Doğrulama oturumu açılamadı. İnternet bağlantını kontrol edip '
        'tekrar dene.',
    canRetry: true,
  ),

  /// Sınıflandıramadığımız her şey. Metni yine de ne yapacağını söylüyor.
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

  /// Kullanıcıya gösterilen başlık: ne olduğu.
  final String title;

  /// Kullanıcıya gösterilen açıklama: **ne yapacağı**.
  final String message;

  /// Aynı yolu tekrar denemenin bir anlamı var mı.
  final bool canRetry;
}

/// Çip okuma yolunun ürettiği hata.
///
/// Sayfalar `catch (e)` içinde tip ayrımı yapmasın diye tek tip; hangi
/// durumun yaşandığı [reason]'da.
class ChipReadException implements Exception {
  const ChipReadException(this.reason, {this.cause});

  final ChipReadFailure reason;

  /// Bu hatayı doğuran özgün hata. Kullanıcıya gösterilmiyor; cihazda çıkan
  /// sorunu teşhis edebilmenin tek yolu bu.
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'ChipReadException(${reason.name})'
      : 'ChipReadException(${reason.name}) (cause: $cause)';
}
