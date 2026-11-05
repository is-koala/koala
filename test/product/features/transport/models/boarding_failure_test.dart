import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/features/transport/models/boarding_failure.dart';
import 'package:koala/product/features/transport/models/transport_error_codes.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../../../support/boarding_fixtures.dart';

void main() {
  group('BoardingFailure.classify — her hata kodu bir duruma', () {
    final cases = <ApiException, BoardingFailure>{
      boardingError(
        TransportErrorCodes.tokenExpired,
        type: ApiErrorType.validation,
        statusCode: 400,
      ): BoardingFailure.tokenExpired,
      boardingError(TransportErrorCodes.wrongShuttle):
          BoardingFailure.wrongShuttle,
      boardingError(TransportErrorCodes.seatNotSelected):
          BoardingFailure.seatNotSelected,
      boardingError(TransportErrorCodes.assignmentNotActive):
          BoardingFailure.assignmentNotActive,
      boardingError(TransportErrorCodes.alreadyBoarded):
          BoardingFailure.alreadyBoarded,
      boardingError(TransportErrorCodes.boardingConcurrent):
          BoardingFailure.concurrent,
      boardingError(TransportErrorCodes.boardingIdempotencyConflict):
          BoardingFailure.retryConflict,
      boardingError(
        TransportErrorCodes.shuttleNotFound,
        type: ApiErrorType.notFound,
        statusCode: 404,
      ): BoardingFailure.invalidQr,
      boardingError(
        TransportErrorCodes.seatAssignmentNotFound,
        type: ApiErrorType.notFound,
        statusCode: 404,
      ): BoardingFailure.invalidQr,
      boardingError(
        TransportErrorCodes.jobAssignmentNotFound,
        type: ApiErrorType.notFound,
        statusCode: 404,
      ): BoardingFailure.invalidQr,
      boardingError(
        'TOO_MANY_REQUESTS',
        type: ApiErrorType.tooManyRequests,
        statusCode: 429,
      ): BoardingFailure.tooManyRequests,
      boardingError(
        'VALIDATION_FAILED',
        type: ApiErrorType.validation,
        statusCode: 400,
      ): BoardingFailure.validation,
      offlineError: BoardingFailure.offline,
      const ApiException(message: 'zaman aşımı', type: ApiErrorType.timeout):
          BoardingFailure.offline,
      const ApiException(message: 'sunucu', type: ApiErrorType.server):
          BoardingFailure.server,
      boardingError('SOMETHING_NEW'): BoardingFailure.unknown,
    };

    for (final entry in cases.entries) {
      test('${entry.key.errorCode ?? entry.key.type} → ${entry.value}', () {
        expect(BoardingFailure.classify(entry.key), entry.value);
      });
    }
  });

  test('yalnız bağlantı, sunucu ve hız sınırı yeniden denenir', () {
    expect(
      BoardingFailure.values.where((failure) => failure.isRetryable).toSet(),
      {
        BoardingFailure.offline,
        BoardingFailure.server,
        BoardingFailure.tooManyRequests,
      },
    );
  });

  test(
    'kuyruktan sonra gelen süre dolumu işverenden işaret istemeyi söyler',
    () {
      final online = BoardingFailure.tokenExpired.message(BoardingActor.worker);
      final queued = BoardingFailure.tokenExpired.message(
        BoardingActor.worker,
        queued: true,
      );

      expect(online, contains('yeniden okutun'));
      expect(queued, contains('İşverenden binişinizi işaretlemesini isteyin'));
    },
  );

  test('her durumun iki tarafta da boş olmayan bir cümlesi var', () {
    for (final failure in BoardingFailure.values) {
      for (final actor in BoardingActor.values) {
        expect(failure.message(actor), isNotEmpty, reason: '$failure $actor');
      }
    }
  });

  test('bilinmeyen hata sunucunun mesajını gösterir', () {
    expect(
      BoardingFailure.unknown.message(
        BoardingActor.employer,
        serverMessage: 'Sunucu mesajı',
      ),
      'Sunucu mesajı',
    );
  });
}
