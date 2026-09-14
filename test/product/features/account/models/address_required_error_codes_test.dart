import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/features/account/models/address_required_error_codes.dart';
import 'package:koala/product/network/api_exception.dart';

void main() {
  ApiException error(String? code) => ApiException(
    message: 'x',
    type: ApiErrorType.validation,
    statusCode: 400,
    errorCode: code,
  );

  group('AddressRequiredErrorCodes.matches', () {
    // İşverenin ödeme kapısı: `JobAssignmentManager.initiatePaymentSession`
    // bireysel işverenin adresi yokken `400` + bu kodla dönüyor.
    test('işverenin adres eksikliğini tanır', () {
      expect(
        AddressRequiredErrorCodes.matches(
          error('JOB_ASSIGNMENT_ADDRESS_NOT_PROVIDED_FOR_EMPLOYER'),
        ),
        isTrue,
      );
    });

    test('çalışanın başvuru kapısını tanır', () {
      expect(
        AddressRequiredErrorCodes.matches(error('APPLICANT_ADDRESS_REQUIRED')),
        isTrue,
      );
    });

    // Aynı akışta ilanın ya da çalışanın adresi de eksik olabilir; o durumda
    // işverenin kendi adres ekranına gitmesi bir şey çözmez.
    test('ilan ve çalışan adres hatalarını işverene yönlendirmez', () {
      for (final code in [
        'JOB_ASSIGNMENT_ADDRESS_NOT_PROVIDED_FOR_JOB',
        'JOB_ASSIGNMENT_ADDRESS_NOT_PROVIDED_FOR_WORKER',
        null,
      ]) {
        expect(AddressRequiredErrorCodes.matches(error(code)), isFalse);
      }
    });
  });
}
