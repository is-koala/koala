/// Fotoğraflı doğrulamanın dört karesi, ekrandaki sırayla. Dördü de zorunlu.
/// [guide] personelin karede ne görmesi gerektiğini anlatıyor; yarım kare
/// reddedilip yeniden yükletilir.
enum IdentityPhotoSlot {
  front(
    fieldName: 'front',
    title: 'Kimlik ön yüzü',
    guide:
        'Kartı düz bir zemine koy; dört köşesi de karede olsun, üstündeki '
        'yazılar parlamadan okunsun.',
    usesFrontCamera: false,
  ),

  back(
    fieldName: 'back',
    title: 'Kimlik arka yüzü',
    guide:
        'Kartı çevir; alt kısımdaki üç satırlık makine okunabilir alan '
        'kesilmeden karede dursun.',
    usesFrontCamera: false,
  ),

  /// Personel kimlikteki fotoğrafla karşılaştırıyor.
  selfie(
    fieldName: 'selfie',
    title: 'Yüz fotoğrafın',
    guide:
        'Aydınlık bir yerde, gözlük ve şapka olmadan doğrudan kameraya bak; '
        'yüzün karenin ortasında ve net olsun.',
    usesFrontCamera: true,
  ),

  /// Kartın sahibinin gönderen kişi olduğunu gösteriyor.
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

  /// Sunucunun `@RequestPart` adı.
  final String fieldName;

  final String title;

  final String guide;

  /// Yüz kareleri ön, kart kareleri arka kamerayla daha net.
  final bool usesFrontCamera;
}
