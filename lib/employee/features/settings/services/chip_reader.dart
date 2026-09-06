import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dmrtd/dmrtd.dart';
// `StatusWord` yalnızca `internal.dart`'tan dışa açılıyor; hangi APDU
// durumunun hangi kullanıcı hatasına karşılık geldiğini ayırmak için
// gerekiyor.
import 'package:dmrtd/internal.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:koala/employee/features/auth/models/chip_evidence.dart';
import 'package:koala/employee/features/settings/models/chip_read_failure.dart';
import 'package:koala/employee/features/settings/models/mrz_key.dart';

/// Çip okumanın kullanıcıya gösterilen aşaması.
///
/// iOS okuma sırasında kendi sistem sayfasını gösteriyor ve bizim
/// tasarımımız onun altında kalıyor; ilerleme oraya da yazılabilsin diye
/// aşama dışarı veriliyor.
enum ChipReadStep {
  waitingForCard('Kartı telefonun arka üst kısmına yasla'),
  openingSession('Kartla güvenli bağlantı kuruluyor'),
  readingDataGroups('Kart bilgileri okunuyor'),
  provingChip('Çip doğrulanıyor'),
  finishing('Okuma tamamlanıyor');

  const ChipReadStep(this.label);

  final String label;
}

/// NFC'nin cihazdaki durumu.
enum NfcAvailability { available, disabled, unsupported }

/// Kimlik kartının çipini okuyup sunucuya gidecek kanıtı üretir.
///
/// Protokolün tamamı `dmrtd`'de (ICAO Doc 9303); burada olan üç şey var:
/// oturumun **BAC mi PACE mi** açılacağına karar vermek, **hangi veri
/// gruplarının** okunacağını seçmek ve `dmrtd`'nin hatalarını kullanıcıya
/// ne yapacağını söyleyen [ChipReadFailure] değerlerine çevirmek.
class ChipReader {
  ChipReader();

  /// Kartın aranma süresi. iOS sistem sayfası da bu süre boyunca açık
  /// kalıyor; kullanıcının kartı çantadan çıkarmasına yetecek kadar uzun,
  /// unutulmuş bir ekranda takılı kalmayacak kadar kısa.
  static const Duration _pollTimeout = Duration(seconds: 30);

  /// Sunucunun ürettiği tek kullanımlık sayının ham uzunluğu
  /// (`IdentityChallengeManager.CHALLENGE_BYTES`). `INTERNAL AUTHENTICATE`
  /// de tam sekiz bayt istiyor.
  static const int _challengeLength = 8;

  /// NFC durumu sorgusunun beklenebileceği süre.
  ///
  /// Sorgu yerli tarafa gidiyor ve **yanıtsız kalabiliyor** — eklentinin
  /// kanalı bağlı değilse `Future` hiç tamamlanmıyor. Süre sınırı olmadan
  /// ekran sonsuza kadar dönen bir göstergede kalırdı; kullanıcının tek
  /// çıkışı geri tuşu olurdu.
  static const Duration _availabilityTimeout = Duration(seconds: 5);

  /// Cihazda NFC var mı, açık mı.
  ///
  /// Okumaya girmeden **önce** sorulması gerekiyor: NFC'si olmayan bir
  /// telefonda kullanıcıyı kart okutmaya çağırmak, sonu olmayan bir döngü.
  Future<NfcAvailability> availability() async {
    try {
      final status = await FlutterNfcKit.nfcAvailability.timeout(
        _availabilityTimeout,
      );

      switch (status) {
        case NFCAvailability.available:
          return NfcAvailability.available;
        case NFCAvailability.disabled:
          return NfcAvailability.disabled;
        case NFCAvailability.not_supported:
          return NfcAvailability.unsupported;
      }
    } on Object {
      // Sorulamadıysa (hata ya da zaman aşımı) donanım yokmuş gibi
      // davranıyoruz: kullanıcıyı açılmayacak bir okumaya sokmaktansa elle
      // girişe yönlendirmek daha az zarar veriyor.
      return NfcAvailability.unsupported;
    }
  }

  /// Kartı okur ve sunucuya gidecek kanıtı döndürür.
  ///
  /// [challenge] sunucudan **kart okunmadan önce** alınmış olmalı: çipe
  /// imzalatılacak şey o. Kart okunduktan sonra alınan bir sayı, imzalanmış
  /// olmayacağı için tekrar korumasını sağlamaz.
  ///
  /// Kartta `DG15` yoksa Active Authentication adımı **atlanıyor** ve akış
  /// yine tamamlanıyor; sunucu bugün bunu kabul ediyor.
  ///
  /// Yalnızca [ChipReadException] yükseltiyor.
  Future<ChipEvidence> read({
    required MrzKey key,
    required String challenge,
    void Function(ChipReadStep step)? onStep,
  }) async {
    final challengeBytes = _decodeChallenge(challenge);
    final provider = _KoalaNfcProvider();

    void step(ChipReadStep value) {
      onStep?.call(value);
      provider.showStep(value.label);
    }

    try {
      step(ChipReadStep.waitingForCard);
      await provider.connect(
        timeout: _pollTimeout,
        iosAlertMessage: ChipReadStep.waitingForCard.label,
      );

      final passport = Passport(provider);

      step(ChipReadStep.openingSession);
      await _openSession(passport, key);

      step(ChipReadStep.readingDataGroups);
      final available = (await passport.readEfCOM()).dgTags;

      final dg1 = await passport.readEfDG1();

      // DG11 kartta olmayabiliyor. Varsa gönderiliyor çünkü MRZ adı
      // ASCII'ye katlıyor: **ÇAĞRI** DG1'de **CAGRI** olarak duruyor.
      final dg11 = available.contains(EfDG11.TAG)
          ? await passport.readEfDG11()
          : null;

      EfDG15? dg15;
      Uint8List? signature;
      if (available.contains(EfDG15.TAG)) {
        dg15 = await passport.readEfDG15();
        step(ChipReadStep.provingChip);
        signature = await passport.activeAuthenticate(challengeBytes);
      }

      step(ChipReadStep.finishing);
      // SOD en sona bırakılıyor: en büyük dosya o ve kart erken çekilirse
      // küçük olanların hepsi zaten okunmuş olur, kullanıcı da daha erken
      // bir noktada değil doğrudan sonda hata görür.
      final sod = await passport.readEfSOD();

      // DG2 kasıtlı olarak okunmuyor: sunucu istemiyor, yüz eşleştirmesi
      // cihazda kalıyor ve büyük dosya okuma süresini gereksiz uzatıyor.

      return ChipEvidence(
        sod: base64Encode(sod.toBytes()),
        dg1: base64Encode(dg1.toBytes()),
        dg11: dg11 == null ? null : base64Encode(dg11.toBytes()),
        dg15: dg15 == null ? null : base64Encode(dg15.toBytes()),
        challenge: signature == null ? null : challenge,
        activeAuthenticationSignature: signature == null
            ? null
            : base64Encode(signature),
      );
    } on ChipReadException {
      rethrow;
    } on Object catch (error) {
      throw ChipReadException(failureFor(error), cause: error);
    } finally {
      // Bağlantı her hâlükârda kapanmalı: iOS'ta açık kalan oturum sistem
      // sayfasını ekranda bırakıyor, Android'de kartı meşgul tutuyor.
      try {
        await provider.disconnect();
      } on Object {
        // Kapanışın kendi hatası, okumanın sonucunu değiştirmiyor.
      }
    }
  }

  /// Oturumu açar: kart PACE destekliyorsa PACE, desteklemiyorsa BAC.
  ///
  /// ICAO Doc 9303 Part 11 §4.1 üç uyumlu yapılandırma tanımlıyor (yalnız
  /// BAC / PACE+BAC / yalnız PACE) ve belge verenlere **1/1/2027'den
  /// itibaren PACE'i zorunlu** kılıyor. Yalnız BAC yazmak kısa vadeli borç
  /// olurdu; ikisi de burada.
  ///
  /// `EF.CardAccess` PACE parametrelerini taşıyan dosya — okunabiliyorsa
  /// kart PACE'i biliyor demektir. PACE denemesi başarısız olursa BAC'e
  /// düşülüyor: geçiş dönemindeki bir kart ikisini de destekliyor olabilir
  /// ve ilkinin başarısızlığı kullanıcının işini bitirmemeli.
  Future<void> _openSession(Passport passport, MrzKey key) async {
    EfCardAccess? cardAccess;
    try {
      cardAccess = await passport.readEfCardAccess();
    } on Object {
      cardAccess = null;
    }

    if (cardAccess != null) {
      try {
        await passport.startSessionPACE(
          DBAKey(
            key.documentNumber,
            key.birthDate,
            key.expiryDate,
            paceMode: true,
          ),
          cardAccess,
        );
        return;
      } on Object {
        // PACE tutmadıysa BAC deneniyor; ikisi de tutmazsa aşağıdaki
        // hata kullanıcıya "bilgiler eşleşmedi" olarak dönüyor.
      }
    }

    await passport.startSession(
      DBAKey(key.documentNumber, key.birthDate, key.expiryDate),
    );
  }

  Uint8List _decodeChallenge(String challenge) {
    final Uint8List bytes;
    try {
      bytes = base64Decode(challenge);
    } on FormatException catch (error) {
      throw ChipReadException(
        ChipReadFailure.challengeUnavailable,
        cause: error,
      );
    }

    if (bytes.length != _challengeLength) {
      throw const ChipReadException(ChipReadFailure.challengeUnavailable);
    }
    return bytes;
  }

  /// `dmrtd`'nin hatasını kullanıcıya ne yapacağını söyleyen bir sebebe
  /// çevirir.
  ///
  /// Ayrı bir statik metot çünkü asıl kıymetli kısım bu ve cihaz olmadan
  /// test edilebilmesi gerekiyor.
  static ChipReadFailure failureFor(Object error) {
    if (error is ChipReadException) return error.reason;

    if (error is PassportError) {
      final status = error.code;

      // 0x6982 / 0x6300 / 0x63CF: güvenlik durumu sağlanmadı. Pratikte tek
      // anlamı var — MRZ'den türetilen anahtar kartın beklediği değil.
      if (status == StatusWord.securityStatusNotSatisfied ||
          (status?.sw1 == 0x63)) {
        return ChipReadFailure.wrongKey;
      }
      // Uygulama ya da dosya yok: okutulan şey eMRTD değil.
      if (status == StatusWord.fileNotFound ||
          status == StatusWord.recordNotFound) {
        return ChipReadFailure.chipUnsupported;
      }
      return ChipReadFailure.cardMoved;
    }

    // Bağlantı koptu, kart uzaklaştı ya da yoklama zaman aşımına uğradı.
    if (error is ComProviderError) return ChipReadFailure.cardMoved;
    if (error is EfParseError) return ChipReadFailure.chipUnsupported;

    return ChipReadFailure.unknown;
  }
}

/// Projenin kendi NFC taşıması.
///
/// `dmrtd`'nin hazır `NfcProvider`'ı yerine yazıldı çünkü iki ayarı
/// geçirmesi gerekiyordu:
///
/// - **`androidCheckNDEF: false`** → `FLAG_READER_SKIP_NDEF_CHECK`. eMRTD
///   NDEF değil; yoklama hem boşa gidiyor hem kartı rahatsız edebiliyor.
/// - Yalnız ISO 14443 A/B taranıyor; 15693 ve 18092 kimlik kartında yok.
///
/// `flutter_nfc_kit` Android'de zaten `enableReaderMode()` kullanıyor,
/// foreground dispatch değil.
///
/// ⚠️ `EXTRA_READER_PRESENCE_CHECK_DELAY` **geçirilemiyor**:
/// `flutter_nfc_kit` `enableReaderMode`'a `extras` olarak `null` veriyor ve
/// bunu dışarı açan bir seçenek sunmuyor. Uzun okumanın agresif varlık
/// yoklamasıyla kesilmesi bu yüzden bugün ayarlanamıyor durumda.
///
/// `NfcProvider`'dan türüyor (`ComProvider`'dan değil) çünkü tabanın
/// istediği `Logger` `logging` paketinden geliyor ve o paket bize yalnızca
/// `dmrtd` üzerinden geçişli olarak ulaşıyor — doğrudan içe aktarmak
/// referans edilmemiş bir pakete bağımlılık olurdu.
class _KoalaNfcProvider extends NfcProvider {
  NFCTag? _tag;

  @override
  Future<void> connect({
    Duration? timeout,
    String iosAlertMessage = 'Kartı telefonun arkasına yasla',
  }) async {
    if (isConnected()) return;

    final NFCTag tag;
    try {
      tag = await FlutterNfcKit.poll(
        timeout: timeout,
        iosAlertMessage: iosAlertMessage,
        iosMultipleTagMessage:
            'Birden fazla kart algılandı, yalnız kimlik kartını bırak.',
        androidCheckNDEF: false,
        readIso14443A: true,
        readIso14443B: true,
        readIso18092: false,
        readIso15693: false,
      );
    } on Object catch (error) {
      throw ChipReadException(ChipReadFailure.cardMoved, cause: error);
    }

    if (tag.type != NFCTagType.iso7816) {
      await FlutterNfcKit.finish();
      throw const ChipReadException(ChipReadFailure.chipUnsupported);
    }
    _tag = tag;
  }

  /// iOS'un sistem NFC sayfasındaki metni günceller; oturum yokken ya da
  /// Android'de sessizce geçiliyor. Hata yutuluyor çünkü ilerleme metnini
  /// yazamamak okumayı bozmamalı.
  void showStep(String message) {
    unawaited(setIosAlertMessage(message).catchError((_) {}));
  }

  @override
  Future<void> disconnect({
    String? iosAlertMessage,
    String? iosErrorMessage,
  }) async {
    if (!isConnected()) return;
    _tag = null;
    await FlutterNfcKit.finish(
      iosAlertMessage: iosAlertMessage,
      iosErrorMessage: iosErrorMessage,
    );
  }

  @override
  bool isConnected() => _tag != null;

  @override
  Future<Uint8List> transceive(Uint8List data, {Duration? timeout}) async {
    try {
      return await FlutterNfcKit.transceive(data, timeout: timeout);
    } on Object catch (error) {
      throw ChipReadException(ChipReadFailure.cardMoved, cause: error);
    }
  }
}
