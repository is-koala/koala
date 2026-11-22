import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dmrtd/dmrtd.dart';
// `StatusWord` yalnız `internal.dart`'tan açık; APDU durumunu kullanıcı
// hatasına eşlemek için gerekli.
import 'package:dmrtd/internal.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:koala/employee/features/auth/models/chip_evidence.dart';
import 'package:koala/employee/features/settings/models/chip_read_failure.dart';
import 'package:koala/employee/features/settings/models/mrz_key.dart';

/// iOS okumada kendi sistem sayfasını gösteriyor; ilerleme oraya da
/// yazılabilsin diye dışarı veriliyor.
enum ChipReadStep {
  waitingForCard('Kartı telefonun arka üst kısmına yasla'),
  openingSession('Kartla güvenli bağlantı kuruluyor'),
  readingDataGroups('Kart bilgileri okunuyor'),
  provingChip('Çip doğrulanıyor'),
  finishing('Okuma tamamlanıyor');

  const ChipReadStep(this.label);

  final String label;
}

enum NfcAvailability { available, disabled, unsupported }

/// Çipi okuyup kanıtı üretir. Protokol `dmrtd`'de; burada BAC/PACE kararı,
/// okunacak veri grupları ve hataların [ChipReadFailure]'a çevrilmesi var.
class ChipReader {
  ChipReader();

  /// Kartı çantadan çıkarmaya yetecek, unutulan ekranda takılmayacak kadar.
  static const Duration _pollTimeout = Duration(seconds: 30);

  /// Sunucunun `CHALLENGE_BYTES`'ı; `INTERNAL AUTHENTICATE` de sekiz bayt
  /// istiyor.
  static const int _challengeLength = 8;

  /// Yerli sorgu yanıtsız kalabiliyor; sınır olmadan ekran sonsuza dek döner.
  static const Duration _availabilityTimeout = Duration(seconds: 5);

  /// Okumadan **önce** sorulmalı: NFC'siz telefonda kart okutmaya çağırmak
  /// sonsuz döngü.
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
      // Sorulamadıysa donanım yok sayılır; açılmayacak okumadan elle giriş iyi.
      return NfcAvailability.unsupported;
    }
  }

  /// Kartı okuyup kanıtı döndürür. [challenge] **kart okunmadan önce** alınmış
  /// olmalı. `DG15` yoksa Active Authentication atlanır, akış tamamlanır.
  /// Yalnız [ChipReadException] yükseltir.
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

      // MRZ adı ASCII'ye katlıyor (**ÇAĞRI** → **CAGRI**); DG11 varsa gider.
      final dg11 = available.contains(EfDG11.TAG)
          ? await passport.readEfDG11()
          : null;

      // DG14: sunucu AA imzasının algoritmasını buradan öğreniyor; AA'dan
      // **önce** okunur. Yardımcı bilgi, okunamazsa akış bozulmaz. Tahmini
      // maliyet
      // 0,2–0,6 sn (4–7 APDU).
      final dg14 = available.contains(EfDG14.TAG)
          ? await readOptional(passport.readEfDG14)
          : null;

      EfDG15? dg15;
      Uint8List? signature;
      if (available.contains(EfDG15.TAG)) {
        dg15 = await passport.readEfDG15();
        step(ChipReadStep.provingChip);
        signature = await passport.activeAuthenticate(challengeBytes);
      }

      step(ChipReadStep.finishing);
      // SOD en sonda: en büyük dosya; kart erken çekilirse hata doğrudan sonda.
      final sod = await passport.readEfSOD();

      // DG2 kasıtlı okunmuyor: sunucu istemiyor, okumayı gereksiz uzatır.

      return ChipEvidence(
        sod: base64Encode(sod.toBytes()),
        dg1: base64Encode(dg1.toBytes()),
        dg11: dg11 == null ? null : base64Encode(dg11.toBytes()),
        dg14: dg14 == null ? null : base64Encode(dg14.toBytes()),
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
      // iOS'ta açık oturum sistem sayfasını bırakıyor, Android'de kartı meşgul
      // tutuyor.
      try {
        await provider.disconnect();
      } on Object {
        // Kapanışın hatası sonucu değiştirmez.
      }
    }
  }

  /// Kart PACE destekliyorsa PACE, yoksa BAC. ICAO 2027'den itibaren PACE'i
  /// zorunlu kılıyor; ikisi de burada. `EF.CardAccess` okunabiliyorsa PACE
  /// deneniyor, başarısızsa BAC'e düşülüyor.
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
        // İkisi de tutmazsa hata "bilgiler eşleşmedi" olur.
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

  /// Yokluğu akışı bozmayacak dosyayı okur; okunamazsa `null`. Yalnız dosya
  /// düzeyindeki hatalar yutulur; bağlantı kopması yükselir, kullanıcı doğru
  /// sebebi görmeli.
  static Future<T?> readOptional<T>(Future<T> Function() read) async {
    try {
      return await read();
    } on PassportError {
      return null;
    } on EfParseError {
      return null;
    }
  }

  /// `dmrtd` hatasını kullanıcı sebebine çevirir; cihazsız test için statik.
  static ChipReadFailure failureFor(Object error) {
    if (error is ChipReadException) return error.reason;

    if (error is PassportError) {
      final status = error.code;

      // Güvenlik durumu sağlanmadı: anahtar kartın beklediği değil.
      if (status == StatusWord.securityStatusNotSatisfied ||
          (status?.sw1 == 0x63)) {
        return ChipReadFailure.wrongKey;
      }
      if (status == StatusWord.fileNotFound ||
          status == StatusWord.recordNotFound) {
        return ChipReadFailure.chipUnsupported;
      }
      return ChipReadFailure.cardMoved;
    }

    if (error is ComProviderError) return ChipReadFailure.cardMoved;
    if (error is EfParseError) return ChipReadFailure.chipUnsupported;

    return ChipReadFailure.unknown;
  }
}

/// Projenin NFC taşıması; `dmrtd`'ninkinden farkı:
/// - **`androidCheckNDEF: false`**: eMRTD NDEF değil, yoklama boşa ve kartı
///   rahatsız edebilir.
/// - Yalnız ISO 14443 A/B.
///
/// ⚠️ `EXTRA_READER_PRESENCE_CHECK_DELAY` geçirilemiyor: `flutter_nfc_kit`
/// `extras`'ı `null` veriyor.
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

  /// iOS sistem sayfasındaki metni günceller; yazamamak okumayı bozmamalı.
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
