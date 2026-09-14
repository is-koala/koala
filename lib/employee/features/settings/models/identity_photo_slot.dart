/// Fotoğraflı kimlik doğrulamanın dört karesi.
///
/// Sıra ekrandaki sıra: kullanıcı önce kartı çekiyor, sonra kendini, en son
/// ikisini birlikte. Sunucunun beklediği parça adı ([fieldName]) sıradan
/// bağımsız; `POST /users/me/identity-documents` dördünü de zorunlu tutuyor
/// ve eksik parçayı `IDENTITY_DOCUMENTS_REQUIRED` ile reddediyor.
///
/// Kadraj metni ([guide]) personelin karede **ne görmesi gerektiğini**
/// anlatıyor; bulanık ya da yarım kare reddedilip yeniden yükletileceği için
/// ilk seferde doğru çekilmesi kullanıcının da yararına.
enum IdentityPhotoSlot {
  /// TCKK ön yüzü: fotoğraf, ad soyad, TCKN ve seri no görünmeli.
  front(
    fieldName: 'front',
    title: 'Kimlik ön yüzü',
    guide:
        'Kartı düz bir zemine koy; dört köşesi de karede olsun, üstündeki '
        'yazılar parlamadan okunsun.',
    usesFrontCamera: false,
  ),

  /// TCKK arka yüzü: MRZ satırları görünmeli.
  back(
    fieldName: 'back',
    title: 'Kimlik arka yüzü',
    guide:
        'Kartı çevir; alt kısımdaki üç satırlık makine okunabilir alan '
        'kesilmeden karede dursun.',
    usesFrontCamera: false,
  ),

  /// Yüz fotoğrafı: personel kimlikteki fotoğrafla karşılaştırıyor.
  selfie(
    fieldName: 'selfie',
    title: 'Yüz fotoğrafın',
    guide:
        'Aydınlık bir yerde, gözlük ve şapka olmadan doğrudan kameraya bak; '
        'yüzün karenin ortasında ve net olsun.',
    usesFrontCamera: true,
  ),

  /// Yüz ve kart aynı karede: kartın sahibinin gönderen kişi olduğunu
  /// gösteriyor.
  together(
    fieldName: 'together',
    title: 'Kimlikle birlikte yüzün',
    guide:
        'Kartın ön yüzünü çenenin altında, kameraya dönük tut; hem yüzün hem '
        'karttaki fotoğraf ve yazılar aynı karede okunsun.',
    usesFrontCamera: true,
  );

  const IdentityPhotoSlot({
    required this.fieldName,
    required this.title,
    required this.guide,
    required this.usesFrontCamera,
  });

  /// Multipart isteğindeki parça adı; sunucunun `@RequestPart` adıyla aynı.
  final String fieldName;

  /// Karenin kullanıcıya gösterilen adı.
  final String title;

  /// Kadraj rehberi: bu karede ne görünmeli.
  final String guide;

  /// Kamera açılırken ön kamera mı tercih edilsin. Yüz kareleri ön kamerayla
  /// çekiliyor; kart kareleri arka kamerayla daha net çıkıyor.
  final bool usesFrontCamera;
}
