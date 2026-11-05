import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/models/job_share_link.dart';
import 'package:koala/product/router/app_link_destination.dart';

void main() {
  group('JobShareLink', () {
    test('paylaşılan adres kanonik web ilan sayfası', () {
      expect(
        JobShareLink.forJob(
          'abc',
          webHosts: {'iskoala.com', 'www.iskoala.com'},
        ).toString(),
        'https://iskoala.com/is-ilanlari/abc',
      );
    });

    test('WEB_HOSTS boşken (geliştirme) yine kanonik web', () {
      expect(
        JobShareLink.forJob('abc', webHosts: const {}).host,
        JobShareLink.canonicalHost,
      );
    });

    // Paylaşılan adres uygulamanın tanıdığı bağlantıyla aynı olmalı;
    // ayrışırsa paylaşılan ilan uygulamada açılmaz.
    test('paylaşılan adres uygulamada ilana geri döner', () {
      final link = JobShareLink.forJob('abc', webHosts: {'iskoala.com'});
      expect(
        AppLinkDestination.routeFor(
          link,
          appScheme: 'koala',
          webHosts: {'iskoala.com'},
        ),
        '/shared-job?id=abc',
      );
      expect(
        AppLinkDestination.httpsPathPrefixes,
        contains(JobShareLink.pathPrefix),
      );
    });

    test('mesaj başlık ve bağlantıyı taşır', () {
      final link = Uri.parse('https://iskoala.com/is-ilanlari/abc');
      expect(
        JobShareLink.message(title: 'Garson', link: link),
        'Garson\nhttps://iskoala.com/is-ilanlari/abc',
      );
    });
  });
}
