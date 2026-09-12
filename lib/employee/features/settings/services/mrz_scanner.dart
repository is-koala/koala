import 'dart:async';

import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:koala/employee/features/settings/models/chip_read_failure.dart';
import 'package:koala/employee/features/settings/models/mrz_key.dart';
import 'package:koala/employee/features/settings/models/mrz_scan_session.dart';

/// Kimlik kartının **arka yüzündeki** MRZ'yi kamerayla okur.
///
/// İki parça var ve ikisi de burada değil:
/// - **OCR** `google_mlkit_text_recognition` — bu paket **genel metin
///   tanıma**, MRZ ayrıştırıcı değil. Ne yaptığını sanıp TD1 beklemek en
///   sık yapılan hata.
/// - **Ayrıştırma ve kontrol hanesi doğrulaması** [MrzKey]'de, saf Dart.
///
/// Kamera kareleri yalnız bellekte işlenir. Bu servis dosya, ham kare veya
/// kişisel veri logu üretmez; bu sınıfa yalnız önceden kırpılmış kadraj girer.
class MrzScanner {
  MrzScanner({
    TextRecognizer? recognizer,
    this.recognitionTimeout = const Duration(seconds: 30),
  }) : _recognizer =
           recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  /// Bu seviyenin altındaki görüntüde küçük MRZ karakterleri güvenilir
  /// ayrışmadığı için kullanıcıdan ışığı artırmasını istiyoruz.
  static const double minimumMeanLuminance = 48;

  /// Play Services modelinin ilk kullanımda hazırlanmasını bekleme sınırı.
  ///
  /// Model indirilemezse platform çağrısı yanıtsız kalabilir. Otuz saniye ilk
  /// indirmeye alan tanırken kullanıcıyı sonsuz yüklemede bırakmaz.
  final Duration recognitionTimeout;

  /// OCR'ın yalnız kadraj içinden ürettiği metni eyleme dönük sonuca çevirir.
  MrzFrameObservation interpretFrame({
    required String roiText,
    required double meanLuminance,
  }) {
    if (meanLuminance < minimumMeanLuminance) {
      return const MrzFrameObservation.invalid(MrzScanGuidance.improveLighting);
    }

    final key = MrzKey.parseTd1(roiText);
    if (key != null) return MrzFrameObservation.valid(key);

    // En az bir MRZ satırına benzeyen uzunluk ve dolgu işareti varsa kart
    // kadrajda ama kare henüz kararlı değildir. Hiç iz yoksa daha çok alan
    // kaplaması için yaklaştırmak, aynı yerde beklemekten daha yararlıdır.
    final compact = roiText.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9<«‹〈]'),
      '',
    );
    final hasMrzTrace =
        compact.length >= 30 && RegExp(r'[<«‹〈]').hasMatch(compact);
    return MrzFrameObservation.invalid(
      hasMrzTrace ? MrzScanGuidance.holdSteady : MrzScanGuidance.moveCloser,
    );
  }

  /// Canlı karenin OCR öncesi kırpılmış MRZ kadrajını işler.
  ///
  /// ML Kit kamera baytını bellekte okur; bu yol dosya üretmez. Kadrajın
  /// dışındaki ad, başlık ve belge metinleri TD1 adayına karışmaz.
  Future<MrzFrameObservation> analyzeLiveFrame(
    InputImage image, {
    required double meanLuminance,
  }) async {
    final recognized = await _process(image);
    return interpretFrame(
      roiText: recognized.text,
      meanLuminance: meanLuminance,
    );
  }

  Future<RecognizedText> _process(InputImage image) async {
    try {
      return await _recognizer.processImage(image).timeout(recognitionTimeout);
    } on TimeoutException catch (error) {
      throw ChipReadException(ChipReadFailure.ocrTimedOut, cause: error);
    } on PlatformException catch (error) {
      if (_isModelDeliveryFailure(error)) {
        // Paketlenmeyen model ağ ya da Play Services yüzünden hazırlanamadı.
        // Görüntünün okunup MRZ üretmemesinden farklı bir çözümü var.
        throw ChipReadException(
          ChipReadFailure.ocrModelUnavailable,
          cause: error,
        );
      }
      throw ChipReadException(ChipReadFailure.mrzUnreadable, cause: error);
    } on Object catch (error) {
      throw ChipReadException(ChipReadFailure.mrzUnreadable, cause: error);
    }
  }

  /// Eklenti bütün ML Kit hatalarını aynı `TextRecognizerError` koduyla
  /// döndürüyor. Bu yüzden yalnız model/modül teslimini açıkça söyleyen
  /// mesajlar indirme hatasıdır; bozuk görüntü gibi diğer yerel hatalar
  /// mevcut MRZ-okunamadı davranışında kalır.
  static bool _isModelDeliveryFailure(PlatformException error) {
    if (error.code != 'TextRecognizerError') return false;

    final message = (error.message ?? '').toLowerCase();
    if (message.contains('google play services')) return true;

    final namesModel = message.contains('model') || message.contains('module');
    final describesDelivery =
        message.contains('download') ||
        message.contains('not available') ||
        message.contains('unavailable') ||
        message.contains('cannot load') ||
        message.contains('failed to load');
    return namesModel && describesDelivery;
  }

  /// Yerel tanıyıcıyı kapatır. Ekran kapanırken çağrılmalı; açık kalan
  /// tanıyıcı yerli tarafta bellek tutuyor.
  Future<void> dispose() => _recognizer.close();
}
