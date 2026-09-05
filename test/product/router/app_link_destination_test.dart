import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/router/app_link_destination.dart';

void main() {
  test('reset-password uygulama linki tokenlı public rotaya dönüşür', () {
    final route = AppLinkDestination.routeFor(
      Uri.parse('koala://reset-password?token=reset-123'),
      appScheme: 'koala',
    );

    expect(route, '/reset-password?token=reset-123');
  });

  test(
    'HTTPS ve benzer host taşıyan bağlantılar uygulama rotasına dönüşmez',
    () {
      for (final link in [
        'https://api.iskoala.com/reset-password?token=reset-123',
        'koala://evil-reset-password?token=reset-123',
        'koala://reset-password.attacker.example?token=reset-123',
      ]) {
        expect(
          AppLinkDestination.routeFor(Uri.parse(link), appScheme: 'koala'),
          isNull,
        );
      }
    },
  );

  test('boş veya birden fazla token taşıyan bağlantı reddedilir', () {
    for (final link in [
      'koala://reset-password?token=',
      'koala://reset-password?token=ilk&token=ikinci',
    ]) {
      expect(
        AppLinkDestination.routeFor(Uri.parse(link), appScheme: 'koala'),
        isNull,
      );
    }
  });

  test('yalnız çalışan flavorın özel şeması kabul edilir', () {
    expect(
      AppLinkDestination.routeFor(
        Uri.parse('koala-staging://reset-password?token=reset-123'),
        appScheme: 'koala-staging',
      ),
      '/reset-password?token=reset-123',
    );
    expect(
      AppLinkDestination.routeFor(
        Uri.parse('koala://reset-password?token=reset-123'),
        appScheme: 'koala-staging',
      ),
      isNull,
    );
  });

  test('kayıt tokenı yalnız tam host ve tek sorgu alanıyla kabul edilir', () {
    expect(
      AppLinkDestination.routeFor(
        Uri.parse('koala://complete-registration?token=registration-123'),
        appScheme: 'koala',
      ),
      '/auth/register-type/register/creating-password'
      '?token=registration-123',
    );
    expect(
      AppLinkDestination.routeFor(
        Uri.parse(
          'koala://complete-registration?token=registration-123&next=/profile',
        ),
        appScheme: 'koala',
      ),
      isNull,
    );
  });

  test(
    'payment-result linki atama ve durumla authenticated rotaya dönüşür',
    () {
      final route = AppLinkDestination.routeFor(
        Uri.parse(
          'koala://payment-result?status=success&assignmentId=assignment-1',
        ),
        appScheme: 'koala',
      );

      expect(route, '/payment-result?status=success&assignmentId=assignment-1');
    },
  );
}
