import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/features/dispute/models/dispute_evidence_error.dart';
import 'package:koala/product/network/api_exception.dart';

void main() {
  group('DisputeEvidenceError', () {
    test('kodlar benzersiz ve her birinin mesajı var', () {
      final codes = DisputeEvidenceError.values.map((e) => e.code).toList();

      expect(codes.toSet(), hasLength(codes.length));
      for (final error in DisputeEvidenceError.values) {
        expect(error.message, isNotEmpty, reason: error.code);
      }
    });

    test(
      'durum değiştiren hatalar yeniden okutur, dosya hataları dosya seçtirir',
      () {
        expect(
          DisputeEvidenceError.disputeClosed.action,
          DisputeEvidenceAction.reload,
        );
        expect(
          DisputeEvidenceError.limitReached.action,
          DisputeEvidenceAction.reload,
        );
        expect(
          DisputeEvidenceError.disputeNotFound.action,
          DisputeEvidenceAction.reload,
        );
        for (final error in [
          DisputeEvidenceError.empty,
          DisputeEvidenceError.tooLarge,
          DisputeEvidenceError.unsupportedType,
          DisputeEvidenceError.resolutionTooHigh,
          DisputeEvidenceError.requestTooLarge,
        ]) {
          expect(
            error.action,
            DisputeEvidenceAction.pickAnother,
            reason: error.code,
          );
        }
        expect(
          DisputeEvidenceError.uploadFailed.action,
          DisputeEvidenceAction.retry,
        );
      },
    );

    test('kodu bulur, tanımayana null döner', () {
      expect(
        DisputeEvidenceError.fromCode('DISPUTE_EVIDENCE_LIMIT_REACHED'),
        DisputeEvidenceError.limitReached,
      );
      expect(DisputeEvidenceError.fromCode('YENI_BIR_KOD'), isNull);
      expect(DisputeEvidenceError.fromCode(null), isNull);
    });
  });

  group('DisputeEvidenceFailure.from', () {
    test('iki 409 farklı cümle ve ikisi de yeniden okutur', () {
      final closed = DisputeEvidenceFailure.from(
        const ApiException(
          message: 'x',
          type: ApiErrorType.dataConflict,
          statusCode: 409,
          errorCode: 'DISPUTE_EVIDENCE_DISPUTE_CLOSED',
        ),
      );
      final limit = DisputeEvidenceFailure.from(
        const ApiException(
          message: 'x',
          type: ApiErrorType.dataConflict,
          statusCode: 409,
          errorCode: 'DISPUTE_EVIDENCE_LIMIT_REACHED',
        ),
      );

      expect(closed.message, isNot(limit.message));
      expect(closed.message, contains('sonuçlanmış'));
      expect(limit.message, contains('5'));
      expect(closed.action, DisputeEvidenceAction.reload);
      expect(limit.action, DisputeEvidenceAction.reload);
    });

    test('zarfsız 413 dosya seçtirir', () {
      final failure = DisputeEvidenceFailure.from(
        const ApiException(
          message: 'x',
          type: ApiErrorType.unknown,
          statusCode: 413,
        ),
      );

      expect(failure.message, contains('boyutu aşıyor'));
      expect(failure.action, DisputeEvidenceAction.pickAnother);
    });

    test('429 bekletip yeniden denetir', () {
      final failure = DisputeEvidenceFailure.from(
        const ApiException(
          message: 'x',
          type: ApiErrorType.tooManyRequests,
          statusCode: 429,
        ),
      );

      expect(failure.action, DisputeEvidenceAction.retry);
      expect(failure.message, contains('bekleyip'));
    });

    test('tanınmayan kod sunucunun mesajını olduğu gibi gösterir', () {
      final failure = DisputeEvidenceFailure.from(
        const ApiException(
          message: 'Sunucunun kendi cümlesi',
          type: ApiErrorType.server,
          statusCode: 500,
          errorCode: 'YENI_BIR_KOD',
        ),
      );

      expect(failure.message, 'Sunucunun kendi cümlesi');
      expect(failure.action, DisputeEvidenceAction.retry);
    });

    test('ağ hatası yeniden denetir', () {
      final failure = DisputeEvidenceFailure.from(
        const ApiException(message: 'İnternet yok', type: ApiErrorType.network),
      );

      expect(failure.action, DisputeEvidenceAction.retry);
      expect(failure.message, 'İnternet yok');
    });
  });
}
