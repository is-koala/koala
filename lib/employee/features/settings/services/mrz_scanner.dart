import 'dart:async';

import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:koala/employee/features/settings/models/chip_read_failure.dart';
import 'package:koala/employee/features/settings/models/mrz_key.dart';
import 'package:koala/employee/features/settings/models/mrz_scan_session.dart';

/// Kart arka yüzündeki MRZ'yi okur. OCR `google_mlkit_text_recognition`
/// (**genel** metin tanıma, MRZ ayrıştırıcı değil); ayrıştırma [MrzKey]'de.
/// Kareler yalnız bellekte, yalnız kırpılmış kadraj girer.
class MrzScanner {
  MrzScanner({
    TextRecognizer? recognizer,
    this.recognitionTimeout = const Duration(seconds: 30),
  }) : _recognizer =
           recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  /// Bunun altında küçük karakterler güvenilir ayrışmıyor; ışık istenir.
  static const double minimumMeanLuminance = 48;

  /// Model indirilemezse çağrı yanıtsız kalabilir; 30 sn ilk indirmeye yeter.
  final Duration recognitionTimeout;

  MrzFrameObservation interpretFrame({
    required String roiText,
    required double meanLuminance,
  }) {
    if (meanLuminance < minimumMeanLuminance) {
      return const MrzFrameObservation.invalid(MrzScanGuidance.improveLighting);
    }

    final key = MrzKey.parseTd1(roiText);
    if (key != null) return MrzFrameObservation.valid(key);

    // MRZ izi varsa kart kadrajda ama kare kararsız; hiç iz yoksa yaklaştırmak
    // beklemekten yararlı.
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

  /// Kırpılmış kadrajı işler; dosya üretilmez, kadraj dışı metin karışmaz.
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
        // Model hazırlanamadı; okunamayan görüntüden farklı çözümü var.
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

  /// Eklenti bütün hataları aynı kodla döndürüyor; yalnız model teslimini
  /// açıkça söyleyen mesajlar indirme hatası.
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

  /// Açık kalan tanıyıcı yerli tarafta bellek tutar.
  Future<void> dispose() => _recognizer.close();
}
