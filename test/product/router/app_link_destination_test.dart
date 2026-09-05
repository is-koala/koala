import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/router/app_link_destination.dart';

void main() {
  test('hesap-dogrula bağlantısı kayıt tamamlama rotasına dönüşür', () {
    final route = AppLinkDestination.routeFor(
      Uri.parse('koala://hesap-dogrula?token=registration-123&utm_source=mail'),
      appScheme: 'koala',
    );

    expect(
      route,
      '/auth/register-type/register/creating-password'
      '?token=registration-123',
    );
    expect(
      AppLinkDestination.routeFor(
        Uri.parse('koala://hesap-dogrula?token=ilk&token=ikinci'),
        appScheme: 'koala',
      ),
      isNull,
    );
  });

  test('sifre-belirle bağlantısı parola belirleme rotasına dönüşür', () {
    final route = AppLinkDestination.routeFor(
      Uri.parse('koala://sifre-belirle?token=set-password-123'),
      appScheme: 'koala',
    );

    expect(
      route,
      '/auth/register-type/register/creating-password'
      '?token=set-password-123',
    );
    expect(
      AppLinkDestination.routeFor(
        Uri.parse('koala://sifre-belirle?token=ilk&token=ikinci'),
        appScheme: 'koala',
      ),
      isNull,
    );
  });

  test('reset-password uygulama linki tokenlı public rotaya dönüşür', () {
    final route = AppLinkDestination.routeFor(
      Uri.parse('koala://reset-password?token=reset-123'),
      appScheme: 'koala',
    );

    expect(route, '/reset-password?token=reset-123');
    expect(
      AppLinkDestination.routeFor(
        Uri.parse('koala://sifre-sifirla?token=ilk&token=ikinci'),
        appScheme: 'koala',
      ),
      isNull,
    );
  });

  test('sifre-sifirla bağlantısı parola sıfırlama rotasına dönüşür', () {
    final route = AppLinkDestination.routeFor(
      Uri.parse('koala://sifre-sifirla?token=reset-123&utm_medium=email'),
      appScheme: 'koala',
    );

    expect(route, '/reset-password?token=reset-123');
  });

  test('eposta-onayla bağlantısı token karşılama rotasına dönüşür', () {
    final route = AppLinkDestination.routeFor(
      Uri.parse('koala://eposta-onayla?token=email-123&utm_campaign=verify'),
      appScheme: 'koala',
    );

    expect(route, '/email-verification?token=email-123');
    expect(
      AppLinkDestination.routeFor(
        Uri.parse('koala://eposta-onayla?token=ilk&token=ikinci'),
        appScheme: 'koala',
      ),
      isNull,
    );
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

  test('user-info, port, path ve fragment taşıyan linkler reddedilir', () {
    for (final link in [
      'koala://user@reset-password?token=reset-123',
      'koala://reset-password:443?token=reset-123',
      'koala://reset-password/path?token=reset-123',
      'koala://reset-password?token=reset-123#fragment',
    ]) {
      expect(
        AppLinkDestination.routeFor(Uri.parse(link), appScheme: 'koala'),
        isNull,
      );
    }
  });

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

  test('kanonik hostların gerekli alanı eksikse bağlantı reddedilir', () {
    for (final link in [
      'koala://hesap-dogrula?utm_source=email',
      'koala://sifre-belirle?utm_source=email',
      'koala://sifre-sifirla?utm_source=email',
      'koala://eposta-onayla?utm_source=email',
      'koala://payment-result?status=success',
      'koala://payment-result?assignmentId=assignment-1',
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

  test('legacy kayıt hostu ek sorgu alanlarını yok sayarak kabul edilir', () {
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
      '/auth/register-type/register/creating-password'
      '?token=registration-123',
    );
  });

  test('legacy reset hostu ek sorgu alanlarını yok sayarak kabul edilir', () {
    expect(
      AppLinkDestination.routeFor(
        Uri.parse('koala://reset-password?token=reset-123&utm_source=legacy'),
        appScheme: 'koala',
      ),
      '/reset-password?token=reset-123',
    );
  });

  test(
    'payment-result linki atama ve durumla authenticated rotaya dönüşür',
    () {
      final route = AppLinkDestination.routeFor(
        Uri.parse(
          'koala://payment-result?status=success&assignmentId=assignment-1'
          '&utm_source=iyzico',
        ),
        appScheme: 'koala',
      );

      expect(route, '/payment-result?status=success&assignmentId=assignment-1');
      expect(
        AppLinkDestination.routeFor(
          Uri.parse(
            'koala://payment-result?status=success&status=failed'
            '&assignmentId=assignment-1',
          ),
          appScheme: 'koala',
        ),
        isNull,
      );
    },
  );
}
