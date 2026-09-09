import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:koala/employee/features/settings/models/chip_read_failure.dart';
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

void main() {
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
          .recognize('/tmp/kimlik.jpg')
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
    'ilk kullanımda boş OCR sonucu model ve görüntü ihtimallerini ayırmaz',
    () async {
      final scanner = MrzScanner(recognizer: _EmptyTextRecognizer());

      await expectLater(
        scanner.recognize('/tmp/kimlik.jpg'),
        throwsA(
          isA<ChipReadException>().having(
            (error) => error.reason,
            'sebep',
            ChipReadFailure.ocrUnavailableOrUnreadable,
          ),
        ),
      );
    },
  );

  test('iOS boş OCR sonucunu Android model sorunu diye göstermez', () async {
    final scanner = MrzScanner(
      recognizer: _EmptyTextRecognizer(),
      usesDownloadableModel: false,
    );

    await expectLater(
      scanner.recognize('/tmp/kimlik.jpg'),
      throwsA(
        isA<ChipReadException>().having(
          (error) => error.reason,
          'sebep',
          ChipReadFailure.mrzUnreadable,
        ),
      ),
    );
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
        scanner.recognize('/tmp/kimlik.jpg'),
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
      scanner.recognize('/tmp/kimlik.jpg'),
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
