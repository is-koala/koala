import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:koala/employee/features/settings/models/chip_read_failure.dart';
import 'package:koala/employee/features/settings/models/mrz_scan_session.dart';
import 'package:koala/employee/features/settings/services/mrz_scanner.dart';

class _PendingTextRecognizer extends TextRecognizer {
  final Completer<RecognizedText> pending = Completer<RecognizedText>();

  @override
  Future<RecognizedText> processImage(InputImage inputImage) => pending.future;

  @override
  Future<void> close() async {}
}

class _FailingTextRecognizer extends TextRecognizer {
  _FailingTextRecognizer(this.error);

  final PlatformException error;

  @override
  Future<RecognizedText> processImage(InputImage inputImage) async {
    throw error;
  }

  @override
  Future<void> close() async {}
}

class _EmptyTextRecognizer extends TextRecognizer {
  @override
  Future<RecognizedText> processImage(InputImage inputImage) async {
    return RecognizedText(text: '', blocks: const []);
  }

  @override
  Future<void> close() async {}
}

class _StaticTextRecognizer extends TextRecognizer {
  _StaticTextRecognizer(this.result);

  final RecognizedText result;

  @override
  Future<RecognizedText> processImage(InputImage inputImage) async => result;

  @override
  Future<void> close() async {}
}

void main() {
  test('karanlık kare kullanıcıyı ışığı artırmaya yönlendirir', () {
    final scanner = MrzScanner(recognizer: _EmptyTextRecognizer());

    final observation = scanner.interpretFrame(roiText: '', meanLuminance: 24);

    expect(observation.guidance, MrzScanGuidance.improveLighting);
    expect(observation.key, isNull);
  });

  test('kadrajda MRZ izi yoksa kullanıcı kartı yaklaştırır', () {
    final scanner = MrzScanner(recognizer: _EmptyTextRecognizer());

    final observation = scanner.interpretFrame(
      roiText: 'TÜRKİYE CUMHURİYETİ',
      meanLuminance: 120,
    );

    expect(observation.guidance, MrzScanGuidance.moveCloser);
  });

  test('OCR öncesi kırpılmış karenin bütün metni ayrıştırılır', () async {
    const mrz =
        'I<TURA01B23456612345678950<<<<\n'
        '9804072F3001019TUR<<<<<<<<<<<8\n'
        'KAYA<<ADA<<<<<<<<<<<<<<<<<<<<<';
    final outside = TextBlock(
      text: mrz,
      lines: mrz
          .split('\n')
          .map(
            (text) => TextLine(
              text: text,
              elements: const [],
              boundingBox: const Rect.fromLTWH(20, 20, 900, 30),
              recognizedLanguages: const [],
              cornerPoints: const <Point<int>>[],
              confidence: 1,
              angle: 0,
            ),
          )
          .toList(),
      boundingBox: const Rect.fromLTWH(20, 20, 900, 110),
      recognizedLanguages: const [],
      cornerPoints: const <Point<int>>[],
    );
    final scanner = MrzScanner(
      recognizer: _StaticTextRecognizer(
        RecognizedText(text: mrz, blocks: [outside]),
      ),
    );

    final observation = await scanner.analyzeLiveFrame(
      InputImage.fromFilePath('/tmp/kullanilmayan.jpg'),
      meanLuminance: 120,
    );

    expect(observation.key?.documentNumber, 'A01B23456');
  });

  test('kadraj içindeki geçerli üç TD1 satırı anahtar üretir', () async {
    const mrz =
        'I<TURA01B23456612345678950<<<<\n'
        '9804072F3001019TUR<<<<<<<<<<<8\n'
        'KAYA<<ADA<<<<<<<<<<<<<<<<<<<<<';
    final lines = <TextLine>[];
    for (final (index, text) in mrz.split('\n').indexed) {
      lines.add(
        TextLine(
          text: text,
          elements: const [],
          boundingBox: Rect.fromLTWH(20, 450 + (index * 45), 900, 30),
          recognizedLanguages: const [],
          cornerPoints: const <Point<int>>[],
          confidence: 1,
          angle: 0,
        ),
      );
    }
    final scanner = MrzScanner(
      recognizer: _StaticTextRecognizer(
        RecognizedText(
          text: mrz,
          blocks: [
            TextBlock(
              text: mrz,
              lines: lines,
              boundingBox: const Rect.fromLTWH(20, 450, 900, 120),
              recognizedLanguages: const [],
              cornerPoints: const <Point<int>>[],
            ),
          ],
        ),
      ),
    );

    final observation = await scanner.analyzeLiveFrame(
      InputImage.fromFilePath('/tmp/kullanilmayan.jpg'),
      meanLuminance: 120,
    );

    expect(observation.key?.documentNumber, 'A01B23456');
  });

  testWidgets('indirilemeyen OCR modeli taramayı sonsuza kadar bekletmez', (
    tester,
  ) async {
    final scanner = MrzScanner(
      recognizer: _PendingTextRecognizer(),
      recognitionTimeout: const Duration(seconds: 5),
    );
    ChipReadException? failure;

    unawaited(
      scanner
          .analyzeLiveFrame(
            InputImage.fromFilePath('/tmp/kullanilmayan.jpg'),
            meanLuminance: 120,
          )
          .then<void>(
            (_) {},
            onError: (Object error, StackTrace stackTrace) {
              failure = error as ChipReadException;
            },
          ),
    );
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();

    expect(failure?.reason, ChipReadFailure.ocrTimedOut);
  });

  test(
    'model dışındaki yerel OCR hatası indirme sorunu diye gösterilmez',
    () async {
      final scanner = MrzScanner(
        recognizer: _FailingTextRecognizer(
          PlatformException(
            code: 'TextRecognizerError',
            message: 'IllegalArgumentException: bozuk görüntü girdisi',
          ),
        ),
      );

      await expectLater(
        scanner.analyzeLiveFrame(
          InputImage.fromFilePath('/tmp/kullanilmayan.jpg'),
          meanLuminance: 120,
        ),
        throwsA(
          isA<ChipReadException>().having(
            (error) => error.reason,
            'sebep',
            ChipReadFailure.mrzUnreadable,
          ),
        ),
      );
    },
  );

  test('indirilmeyi bekleyen ML Kit modülü doğru çözümle gösterilir', () async {
    final scanner = MrzScanner(
      recognizer: _FailingTextRecognizer(
        PlatformException(
          code: 'TextRecognizerError',
          message:
              'MlKitException: Waiting for the text recognition module '
              'to be downloaded.',
        ),
      ),
    );

    await expectLater(
      scanner.analyzeLiveFrame(
        InputImage.fromFilePath('/tmp/kullanilmayan.jpg'),
        meanLuminance: 120,
      ),
      throwsA(
        isA<ChipReadException>().having(
          (error) => error.reason,
          'sebep',
          ChipReadFailure.ocrModelUnavailable,
        ),
      ),
    );
  });
}
