import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/network/api_config.dart';
import 'package:koala/product/router/app_link_destination.dart';

/// Birim testlerin kullandığı örnek host kümeleri; gerçek yapılandırma
/// `configuredWebHosts` ile okunur.
const productionHosts = {'iskoala.com', 'www.iskoala.com'};
const stagingHosts = {'iskoala.com'};

/// `config/<flavor>.json` dosyasındaki `WEB_HOSTS`, uygulamanın okuduğu yoldan.
Set<String> configuredWebHosts(String flavor) {
  final decoded =
      jsonDecode(File('config/$flavor.json').readAsStringSync())
          as Map<String, dynamic>;
  return ApiConfig.resolveWebHosts(
    flavor: flavor,
    configuredHosts: decoded['WEB_HOSTS'] as String,
  );
}

void main() {
  test('hesap-dogrula bağlantısı kayıt tamamlama rotasına dönüşür', () {
    final route = AppLinkDestination.routeFor(
      Uri.parse('koala://hesap-dogrula?token=registration-123&utm_source=mail'),
      appScheme: 'koala',
      webHosts: productionHosts,
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
        webHosts: productionHosts,
      ),
      isNull,
    );
  });

  test('sifre-belirle bağlantısı parola belirleme rotasına dönüşür', () {
    final route = AppLinkDestination.routeFor(
      Uri.parse('koala://sifre-belirle?token=set-password-123'),
      appScheme: 'koala',
      webHosts: productionHosts,
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
        webHosts: productionHosts,
      ),
      isNull,
    );
  });

  test('reset-password uygulama linki tokenlı public rotaya dönüşür', () {
    final route = AppLinkDestination.routeFor(
      Uri.parse('koala://reset-password?token=reset-123'),
      appScheme: 'koala',
      webHosts: productionHosts,
    );

    expect(route, '/reset-password?token=reset-123');
    expect(
      AppLinkDestination.routeFor(
        Uri.parse('koala://sifre-sifirla?token=ilk&token=ikinci'),
        appScheme: 'koala',
        webHosts: productionHosts,
      ),
      isNull,
    );
  });

  test('sifre-sifirla bağlantısı parola sıfırlama rotasına dönüşür', () {
    final route = AppLinkDestination.routeFor(
      Uri.parse('koala://sifre-sifirla?token=reset-123&utm_medium=email'),
      appScheme: 'koala',
      webHosts: productionHosts,
    );

    expect(route, '/reset-password?token=reset-123');
  });

  test('eposta-onayla bağlantısı token karşılama rotasına dönüşür', () {
    final route = AppLinkDestination.routeFor(
      Uri.parse('koala://eposta-onayla?token=email-123&utm_campaign=verify'),
      appScheme: 'koala',
      webHosts: productionHosts,
    );

    expect(route, '/email-verification?token=email-123');
    expect(
      AppLinkDestination.routeFor(
        Uri.parse('koala://eposta-onayla?token=ilk&token=ikinci'),
        appScheme: 'koala',
        webHosts: productionHosts,
      ),
      isNull,
    );
  });

  test('production HTTPS bağlantıları aynı uygulama rotalarına dönüşür', () {
    expect(
      AppLinkDestination.routeFor(
        Uri.parse('https://iskoala.com/sifre-belirle?token=set-password-123'),
        appScheme: 'koala',
        webHosts: productionHosts,
      ),
      '/auth/register-type/register/creating-password'
      '?token=set-password-123',
    );
    expect(
      AppLinkDestination.routeFor(
        Uri.parse('https://www.iskoala.com/sifre-sifirla?token=reset-123'),
        appScheme: 'koala',
        webHosts: productionHosts,
      ),
      '/reset-password?token=reset-123',
    );
    expect(
      AppLinkDestination.routeFor(
        Uri.parse(
          'https://iskoala.com/payment/result?status=success'
          '&assignmentId=assignment-1',
        ),
        appScheme: 'koala',
        webHosts: productionHosts,
      ),
      '/payment-result?status=success&assignmentId=assignment-1',
    );
  });

  test(
    'iki flavor da e-postadaki iskoala.com kayıt bağlantısını aynı rotaya çevirir',
    () {
      // Backend e-postaya https://iskoala.com/hesap-dogrula?token=… yazıyor;
      // staging de production web'ini kullandığı için ikisi de açmalı (#155).
      for (final (flavor, scheme) in [
        ('staging', 'koala-staging'),
        ('production', 'koala'),
      ]) {
        expect(
          AppLinkDestination.routeFor(
            Uri.parse('https://iskoala.com/hesap-dogrula?token=x'),
            appScheme: scheme,
            webHosts: configuredWebHosts(flavor),
          ),
          '/auth/register-type/register/creating-password?token=x',
          reason: flavor,
        );
      }
    },
  );

  test('HTTPS hostu şemadan değil yapılandırmadan gelir', () {
    expect(
      AppLinkDestination.routeFor(
        Uri.parse('https://iskoala.com/eposta-onayla?token=email-123'),
        appScheme: 'koala-staging',
        webHosts: stagingHosts,
      ),
      '/email-verification?token=email-123',
    );
    expect(
      AppLinkDestination.routeFor(
        Uri.parse('https://staging.iskoala.com/eposta-onayla?token=email-123'),
        appScheme: 'koala-staging',
        webHosts: stagingHosts,
      ),
      isNull,
    );
    expect(
      AppLinkDestination.routeFor(
        Uri.parse('https://staging.iskoala.com/eposta-onayla?token=email-123'),
        appScheme: 'koala-staging',
        webHosts: const {'staging.iskoala.com'},
      ),
      '/email-verification?token=email-123',
    );
    expect(
      AppLinkDestination.routeFor(
        Uri.parse('https://www.iskoala.com/eposta-onayla?token=email-123'),
        appScheme: 'koala-staging',
        webHosts: stagingHosts,
      ),
      isNull,
    );
  });

  test('host listesi boşken hiçbir HTTPS bağlantısı kabul edilmez', () {
    expect(
      AppLinkDestination.routeFor(
        Uri.parse('https://iskoala.com/hesap-dogrula?token=x'),
        appScheme: 'koala-dev',
        webHosts: const {},
      ),
      isNull,
    );
    expect(
      AppLinkDestination.routeFor(
        Uri.parse('koala-dev://hesap-dogrula?token=x'),
        appScheme: 'koala-dev',
        webHosts: const {},
      ),
      '/auth/register-type/register/creating-password?token=x',
    );
  });

  test('davet HTTPS yolu kimliği yoldan okuyup davet rotasına çevirir', () {
    const id = '11111111-1111-1111-1111-111111111111';
    expect(
      AppLinkDestination.routeFor(
        Uri.parse('https://iskoala.com/davet/$id?utm_source=mail'),
        appScheme: 'koala',
        webHosts: productionHosts,
      ),
      '/company-invitation?id=$id',
    );
    expect(
      AppLinkDestination.routeFor(
        Uri.parse('https://iskoala.com/davet/$id?id=baska'),
        appScheme: 'koala',
        webHosts: productionHosts,
      ),
      '/company-invitation?id=$id',
    );
    for (final link in [
      'https://iskoala.com/davet',
      'https://iskoala.com/davet/',
      'https://iskoala.com/davet/%20',
      'https://iskoala.com/davet/$id/ek',
      'https://iskoala.com/davet?id=$id',
      'https://iskoala.com/company-invitation?id=$id',
    ]) {
      expect(
        AppLinkDestination.routeFor(
          Uri.parse(link),
          appScheme: 'koala',
          webHosts: productionHosts,
        ),
        isNull,
        reason: link,
      );
    }
  });

  test('HTTPS sözleşmesi bilinmeyen host ve yolları reddeder', () {
    for (final link in [
      'https://api.iskoala.com/reset-password?token=reset-123',
      'https://iskoala.com/reset-password?token=reset-123',
      'https://iskoala.com/sifre-sifirla/ek?token=reset-123',
      'https://iskoala.com/payment-result?status=success&assignmentId=1',
      'http://iskoala.com/sifre-sifirla?token=reset-123',
      'koala://evil-reset-password?token=reset-123',
      'koala://reset-password.attacker.example?token=reset-123',
    ]) {
      expect(
        AppLinkDestination.routeFor(
          Uri.parse(link),
          appScheme: 'koala',
          webHosts: productionHosts,
        ),
        isNull,
      );
    }
  });

  test('user-info, port, path ve fragment taşıyan linkler reddedilir', () {
    for (final link in [
      'koala://user@reset-password?token=reset-123',
      'koala://reset-password:443?token=reset-123',
      'koala://reset-password/path?token=reset-123',
      'koala://reset-password?token=reset-123#fragment',
    ]) {
      expect(
        AppLinkDestination.routeFor(
          Uri.parse(link),
          appScheme: 'koala',
          webHosts: productionHosts,
        ),
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
        AppLinkDestination.routeFor(
          Uri.parse(link),
          appScheme: 'koala',
          webHosts: productionHosts,
        ),
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
        AppLinkDestination.routeFor(
          Uri.parse(link),
          appScheme: 'koala',
          webHosts: productionHosts,
        ),
        isNull,
      );
    }
  });

  test('yalnız çalışan flavorın özel şeması kabul edilir', () {
    expect(
      AppLinkDestination.routeFor(
        Uri.parse('koala-staging://reset-password?token=reset-123'),
        appScheme: 'koala-staging',
        webHosts: stagingHosts,
      ),
      '/reset-password?token=reset-123',
    );
    expect(
      AppLinkDestination.routeFor(
        Uri.parse('koala://reset-password?token=reset-123'),
        appScheme: 'koala-staging',
        webHosts: stagingHosts,
      ),
      isNull,
    );
  });

  test('legacy kayıt hostu ek sorgu alanlarını yok sayarak kabul edilir', () {
    expect(
      AppLinkDestination.routeFor(
        Uri.parse('koala://complete-registration?token=registration-123'),
        appScheme: 'koala',
        webHosts: productionHosts,
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
        webHosts: productionHosts,
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
        webHosts: productionHosts,
      ),
      '/reset-password?token=reset-123',
    );
  });

  test(
    'company-invitation bağlantısı davet kimliğiyle authenticated rotaya dönüşür',
    () {
      final route = AppLinkDestination.routeFor(
        Uri.parse(
          'koala://company-invitation?id=11111111-1111-1111-1111-111111111111'
          '&utm_source=mail',
        ),
        appScheme: 'koala',
        webHosts: productionHosts,
      );

      expect(
        route,
        '/company-invitation?id=11111111-1111-1111-1111-111111111111',
      );
      expect(
        AppLinkDestination.routeFor(
          Uri.parse('koala://company-invitation?id=ilk&id=ikinci'),
          appScheme: 'koala',
          webHosts: productionHosts,
        ),
        isNull,
      );
    },
  );

  test('company-invitation kimliği yoksa veya boşsa reddedilir', () {
    for (final link in [
      'koala://company-invitation',
      'koala://company-invitation?id=',
      'koala://company-invitation?utm_source=mail',
      'koala://company-invitation?id=ilk&id=ikinci',
      'koala://user@company-invitation?id=invite-1',
      'koala://company-invitation:443?id=invite-1',
      'koala://company-invitation/path?id=invite-1',
      'koala://company-invitation?id=invite-1#fragment',
    ]) {
      expect(
        AppLinkDestination.routeFor(
          Uri.parse(link),
          appScheme: 'koala',
          webHosts: productionHosts,
        ),
        isNull,
      );
    }
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
        webHosts: productionHosts,
      );

      expect(route, '/payment-result?status=success&assignmentId=assignment-1');
      expect(
        AppLinkDestination.routeFor(
          Uri.parse(
            'koala://payment-result?status=success&status=failed'
            '&assignmentId=assignment-1',
          ),
          appScheme: 'koala',
          webHosts: productionHosts,
        ),
        isNull,
      );
    },
  );

  group('paylaşılan ilan', () {
    String? route(String link, {Set<String> hosts = productionHosts}) =>
        AppLinkDestination.routeFor(
          Uri.parse(link),
          appScheme: 'koala',
          webHosts: hosts,
        );

    test('web ilan sayfası bağlantısı paylaşılan ilan rotasına dönüşür', () {
      expect(
        route('https://iskoala.com/is-ilanlari/7f421e5d'),
        '/shared-job?id=7f421e5d',
      );
      expect(
        route('https://www.iskoala.com/is-ilanlari/7f421e5d'),
        '/shared-job?id=7f421e5d',
      );
    });

    test('özel şemada kimlik sorgu alanından okunur', () {
      expect(route('koala://job?id=7f421e5d'), '/shared-job?id=7f421e5d');
      expect(route('koala://job'), isNull);
    });

    test('ilan listesi ve kimliksiz yol uygulamaya verilmez', () {
      expect(route('https://iskoala.com/is-ilanlari'), isNull);
      expect(route('https://iskoala.com/is-ilanlari/'), isNull);
      expect(route('https://iskoala.com/is-ilanlari/a/b'), isNull);
    });

    test('tanınmayan host kabul edilmez', () {
      expect(route('https://baska.com/is-ilanlari/7f421e5d'), isNull);
    });
  });
}
